package com.release;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;

import com.applozic.mobicomkit.api.account.user.MobiComUserPreference;

/**
 * Splash Screen for 1000ms.
 * If user is already logged in then go to MainActivity.Else Open LoginActivity.
 * MobiComUserPreference.isLoggedIn() method is used to check if user is logged in.
 */
public class SplashScreenActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_splash_screen);

        new Handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (MobiComUserPreference.getInstance(SplashScreenActivity.this).isLoggedIn()) {
                    Intent mainIntent = new Intent(SplashScreenActivity.this, MainActivity.class);
                    SplashScreenActivity.this.startActivity(mainIntent);
                    SplashScreenActivity.this.finish();
                } else {
                    Intent mainIntent = new Intent(SplashScreenActivity.this, LoginActivity.class);
                    SplashScreenActivity.this.startActivity(mainIntent);
                    SplashScreenActivity.this.finish();
                }
            }
        }, 1000);

    }
}
