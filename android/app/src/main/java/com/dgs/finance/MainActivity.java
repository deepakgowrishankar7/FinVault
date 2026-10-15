package com.dgs.finance;

import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintManager;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.widget.Toast;

import com.getcapacitor.BridgeActivity;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

public class MainActivity extends BridgeActivity {

    @Override
    public void onStart() {
        super.onStart();
        try {
            WebView webView = getBridge().getWebView();
            if (webView != null) {
                webView.addJavascriptInterface(new NativeBridge(), "AndroidNativeApp");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public class NativeBridge {

        @JavascriptInterface
        public void printDocument(final String docName) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    try {
                        WebView webView = getBridge().getWebView();
                        if (webView != null) {
                            PrintManager printManager = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                            String printJobName = (docName != null && !docName.isEmpty()) ? docName : "FinVault_Document";
                            PrintDocumentAdapter printAdapter = webView.createPrintDocumentAdapter(printJobName);
                            printManager.print(printJobName, printAdapter, new PrintAttributes.Builder().build());
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                        Toast.makeText(MainActivity.this, "Printing error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                    }
                }
            });
        }

        @JavascriptInterface
        public boolean saveFileToDownloads(final String base64Data, final String filename, final String mimeType) {
            try {
                byte[] fileBytes = Base64.decode(base64Data, Base64.DEFAULT);
                String cleanMime = (mimeType != null && !mimeType.isEmpty()) ? mimeType : "application/octet-stream";
                String cleanName = (filename != null && !filename.isEmpty()) ? filename : ("FinVault_" + System.currentTimeMillis() + ".dat");

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.Downloads.DISPLAY_NAME, cleanName);
                    values.put(MediaStore.Downloads.MIME_TYPE, cleanMime);
                    values.put(MediaStore.Downloads.IS_PENDING, 1);

                    Uri uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                    if (uri != null) {
                        try (OutputStream os = getContentResolver().openOutputStream(uri)) {
                            if (os != null) {
                                os.write(fileBytes);
                                os.flush();
                            }
                        }
                        values.clear();
                        values.put(MediaStore.Downloads.IS_PENDING, 0);
                        getContentResolver().update(uri, values, null, null);

                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                Toast.makeText(MainActivity.this, "Saved to Downloads: " + cleanName, Toast.LENGTH_LONG).show();
                            }
                        });
                        return true;
                    }
                } else {
                    File downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
                    if (!downloadsDir.exists()) downloadsDir.mkdirs();
                    File outFile = new File(downloadsDir, cleanName);
                    try (FileOutputStream fos = new FileOutputStream(outFile)) {
                        fos.write(fileBytes);
                        fos.flush();
                    }
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            Toast.makeText(MainActivity.this, "Saved to Downloads: " + cleanName, Toast.LENGTH_LONG).show();
                        }
                    });
                    return true;
                }
            } catch (Exception e) {
                e.printStackTrace();
                final String err = e.getMessage();
                runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        Toast.makeText(MainActivity.this, "Download error: " + err, Toast.LENGTH_LONG).show();
                    }
                });
            }
            return false;
        }
    }
}
