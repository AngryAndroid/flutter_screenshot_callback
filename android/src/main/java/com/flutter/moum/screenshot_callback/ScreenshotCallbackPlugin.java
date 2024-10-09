package com.flutter.moum.screenshot_callback;

import android.content.Context;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import kotlin.Unit;
import kotlin.jvm.functions.Function1;

public class ScreenshotCallbackPlugin implements MethodCallHandler, FlutterPlugin {
    private Context applicationContext;
    private MethodChannel channel;
    private ScreenshotDetector detector;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter.moum/screenshot_callback");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = null;
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(MethodCall call, @NonNull Result result) {
        if (call.method.equals("initialize")) {
            if (applicationContext != null) {
                detector = new ScreenshotDetector(applicationContext, new Function1<String, Unit>() {
                    @Override
                    public Unit invoke(final String screenshotFilePath) {
                        if (channel != null) {
                            try {
                                channel.invokeMethod("onCallback", screenshotFilePath);
                            } catch (Exception ignored) {
                            }
                        }
                        return null;
                    }
                });
                detector.start();
            }

            result.success("initialize");
        } else if (call.method.equals("dispose")) {
            if (detector != null) {
                detector.stop();
            }
            detector = null;

            result.success("dispose");
        } else {
            result.notImplemented();
        }
    }
}
