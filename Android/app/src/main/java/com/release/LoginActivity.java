package com.release;

import android.app.Activity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Handler;
import android.support.v7.app.AlertDialog;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.Patterns;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Toast;

import com.applozic.mobicomkit.Applozic;
import com.applozic.mobicomkit.api.account.register.RegistrationResponse;
import com.applozic.mobicomkit.api.account.user.MobiComUserPreference;
import com.applozic.mobicomkit.api.account.user.PushNotificationTask;
import com.applozic.mobicomkit.api.account.user.User;
import com.applozic.mobicomkit.api.account.user.UserLoginTask;
import com.applozic.mobicomkit.listners.AlLoginHandler;
import com.applozic.mobicomkit.listners.AlPushNotificationHandler;
import com.applozic.mobicommons.commons.core.utils.Utils;

public class LoginActivity extends AppCompatActivity {

    private Button loginButton;
    private EditText mUserId;
    private EditText mEmailAddress;
    private EditText mPhoneNumber;
    private EditText mPassword;
    private EditText mDisplayName;
    private boolean exit = false;
    private View progressView;
    private LinearLayout loginForm;

    private MobiComUserPreference mobiComUserPreference;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        setContentView(R.layout.activity_login);

        mUserId = findViewById(R.id.user_id);
        mEmailAddress = findViewById(R.id.email);
        mPhoneNumber = findViewById(R.id.phone_number);
        mPassword = findViewById(R.id.password);
        mDisplayName = findViewById(R.id.display_name);
        loginButton = findViewById(R.id.login_button);
        progressView = findViewById(R.id.login_progress);
        loginForm = findViewById(R.id.login_form);
        Applozic.init(this,"applozic-sample-app");
        loginButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Utils.toggleSoftKeyBoard(LoginActivity.this, true);
                attemptLogin(User.AuthenticationType.APPLOZIC);
            }
        });
        mobiComUserPreference = MobiComUserPreference.getInstance(this);
    }

    /**
     * This functions contain the code for user login.
     * @param authenticationType
     */
    private void attemptLogin(User.AuthenticationType authenticationType){
        mUserId.setError(null);
        mEmailAddress.setError(null);
        mPhoneNumber.setError(null);
        mPassword.setError(null);
        mDisplayName.setError(null);

        // Store values at the time of the login attempt.
        String email = mEmailAddress.getText().toString();
        String phoneNumber = mPhoneNumber.getText().toString();
        String userId = mUserId.getText().toString().trim();
        String password = mPassword.getText().toString();
        String displayName = mDisplayName.getText().toString();

        boolean cancel = false;
        View focusView = null;

        if (TextUtils.isEmpty(mUserId.getText().toString()) || mUserId.getText().toString().trim().length() == 0) {
            mUserId.setError("Error field required");
            focusView = mUserId;
            cancel = true;
        }
        // Check for a valid password, if the user entered one.
        if ((TextUtils.isEmpty(mPassword.getText().toString()) || mPassword.getText().toString().trim().length() == 0) && !isPasswordValid(mPassword.getText().toString())) {
            mPassword.setError("Invalid Password");
            focusView = mPassword;
            cancel = true;
        }

        // Check for a valid email address.
        if (TextUtils.isEmpty(email)) {
            mEmailAddress.setError("Email field required");
            focusView = mEmailAddress;
            cancel = true;
        }

        if (cancel) {
            // There was an error; don't attempt login and focus the first
            // form field with an error.
            focusView.requestFocus();
        } else {
            progressView.setVisibility(View.VISIBLE);
            loginForm.setVisibility(View.INVISIBLE);
            User user = new User();
            user.setUserId(userId);
            user.setEmail(email);
            user.setPassword(password);
            user.setDisplayName(displayName);
            user.setContactNumber(phoneNumber);
            user.setAuthenticationTypeId(authenticationType.getValue());

            Applozic.loginUser(this, user, new AlLoginHandler() {
                @Override
                public void onSuccess(RegistrationResponse registrationResponse, Context context) {
                    Applozic.registerForPushNotification(LoginActivity.this, new AlPushNotificationHandler() {
                        @Override
                        public void onSuccess(RegistrationResponse registrationResponse) {

                        }

                        @Override
                        public void onFailure(RegistrationResponse registrationResponse, Exception exception) {

                        }

                    });
                    progressView.setVisibility(View.INVISIBLE);
                    //starting main MainActivity
                    Intent mainActvity = new Intent(context, MainActivity.class);
                    startActivity(mainActvity);
                    finish();
                }

                @Override
                public void onFailure(RegistrationResponse registrationResponse, Exception exception) {
                    progressView.setVisibility(View.INVISIBLE);
                    loginForm.setVisibility(View.INVISIBLE);
                    loginButton.setVisibility(View.VISIBLE);
                    AlertDialog alertDialog = new AlertDialog.Builder(LoginActivity.this).create();
                    alertDialog.setTitle("Alert");
                    alertDialog.setMessage(exception.toString());
                    alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL, "Alert",
                            new DialogInterface.OnClickListener() {
                                public void onClick(DialogInterface dialog, int which) {
                                    dialog.dismiss();
                                }
                            });
                    if (!isFinishing()) {
                        alertDialog.show();
                    }
                }
            });

            loginButton.setVisibility(View.INVISIBLE);
        }
    }

    private boolean isEmailValid(String email) {
        return !TextUtils.isEmpty(email) && Patterns.EMAIL_ADDRESS.matcher(email).matches();
    }

    private boolean isPasswordValid(String password) {
        //TODO: Replace this with your own logic
        return password.length() > 5;
    }

    @Override
    public void onBackPressed() {

        if (exit) {
            finish();
        } else {
            Toast.makeText(this, "Press back again to exit", Toast.LENGTH_SHORT).show();
            exit = true;

            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    exit = false;
                }
            }, 3000);
        }

    }
}
