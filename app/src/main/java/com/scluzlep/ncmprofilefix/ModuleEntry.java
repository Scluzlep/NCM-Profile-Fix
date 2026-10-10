package com.scluzlep.ncmprofilefix;

import android.util.Log;
import org.json.JSONArray;
import org.json.JSONObject;
import java.lang.reflect.Method;
import java.util.concurrent.atomic.AtomicInteger;
import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;

/**
 * Compatibility fix for NetEase Cloud Music 8.10.50.
 *
 * Old Comment.fromJson expects "alias" to be a JSONArray. The private
 * PERSONAL_MY_COMMENT homepage block can include String or JSON null instead.
 * The module modifies only JSONObject.getJSONArray("alias") results while
 * Comment.fromJson appears in the current thread's stack.
 */
public final class ModuleEntry extends XposedModule {
    private static final String TAG = "NCMProfileFix";
    private static final String TARGET = "com.netease.cloudmusic";
    private static final String COMMENT_CLASS = "com.netease.cloudmusic.meta.Comment";
    private final AtomicInteger fixedCount = new AtomicInteger();
    private boolean installed;

    @Override
    public void onPackageReady(PackageReadyParam param) {
        if (!TARGET.equals(param.getPackageName()) || !param.isFirstPackage() || installed) {
            return;
        }
        try {
            Method method = JSONObject.class.getDeclaredMethod("getJSONArray", String.class);
            hook(method)
                .setExceptionMode(XposedInterface.ExceptionMode.PROTECTIVE)
                .intercept(chain -> {
                    if (!"alias".equals(chain.getArg(0))) {
                        return chain.proceed();
                    }
                    Object thiz = chain.getThisObject();
                    if (!(thiz instanceof JSONObject)) {
                        return chain.proceed();
                    }
                    Object raw = ((JSONObject) thiz).opt("alias");
                    if (!(raw instanceof String) && raw != JSONObject.NULL) {
                        return chain.proceed();
                    }
                    if (!insideCommentParser()) {
                        return chain.proceed();
                    }
                    JSONArray replacement = new JSONArray();
                    if (raw instanceof String && !((String) raw).isEmpty()) {
                        replacement.put(raw);
                    }
                    int count = fixedCount.incrementAndGet();
                    if (count <= 30) {
                        Log.i(TAG, "Normalized Comment.fromJson alias (" + count + ")");
                    }
                    return replacement;
                });
            installed = true;
            Log.i(TAG, "Installed in " + TARGET + ", API " + getApiVersion());
        } catch (Throwable t) {
            Log.e(TAG, "Hook installation failed; app left unchanged", t);
        }
    }

    private static boolean insideCommentParser() {
        for (StackTraceElement frame : Thread.currentThread().getStackTrace()) {
            if (COMMENT_CLASS.equals(frame.getClassName())
                && "fromJson".equals(frame.getMethodName())) {
                return true;
            }
        }
        return false;
    }
}
