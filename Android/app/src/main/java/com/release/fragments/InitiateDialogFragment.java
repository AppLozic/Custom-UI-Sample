package com.release.fragments;

import android.app.Dialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import androidx.fragment.app.DialogFragment;
import androidx.appcompat.app.AlertDialog;
import android.text.TextUtils;
import android.widget.EditText;
import android.widget.Toast;

import com.applozic.mobicomkit.contact.AppContactService;
import com.release.R;
import com.release.activity.ConversationActivity;


public class InitiateDialogFragment extends DialogFragment implements DialogInterface.OnClickListener {

    private EditText inputEditText;
    private AppContactService appContactService;

    /**
     * This method creates a dialog to start chat using userId
     * @param savedInstanceState
     * @return it returns the dialog object
     */
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        appContactService = new AppContactService(getActivity());
        inputEditText = new EditText(getActivity());
        return new AlertDialog.Builder(getActivity()).setTitle(R.string.initiate_chat_info).setMessage(R.string.enter_user_id_info)
                .setPositiveButton(R.string.start, this).setNegativeButton(R.string.cancel, null).setView(inputEditText).create();
    }

    /**
     * This method handles the click event in the dialogue.
     * When Start is clicked, it checks if the userid entered is valid or not. It does not create a contact if contact does not exist but simply displays error.
     * @param dialog It is a reference to the dialog interface
     * @param position It is the position of the clicked item
     */
    @Override
    public void onClick(DialogInterface dialog, int position) {

        switch (position) {
            case -1:
                String editTextValue = inputEditText.getText().toString();
                if (TextUtils.isEmpty(editTextValue) || inputEditText.getText().toString().trim().length() == 0) {
                    Toast.makeText(getActivity(), R.string.empty_user_id_info, Toast.LENGTH_SHORT).show();
                    return;
                }
                if(appContactService.isContactExists(editTextValue)){
                    Intent intent = new Intent(getActivity(), ConversationActivity.class);
                    intent.putExtra("TYPE", "CONTACT");
                    intent.putExtra("ID", editTextValue);
                    intent.putExtra("CHECK_INTENT","ACTIVITY");
                    startActivity(intent);
                    dialog.dismiss();
                }else{
                    Toast.makeText(getActivity(), "Wrong UserId",Toast.LENGTH_SHORT).show();
                }

                break;
            case -2:
                dialog.dismiss();
                break;
        }

    }

}
