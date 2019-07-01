package com.release.activity;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Color;
import android.media.MediaRecorder;
import android.net.ConnectivityManager;
import android.net.Uri;
import android.os.Build;
import android.os.Parcelable;
import android.provider.MediaStore;
import android.provider.Settings;
import android.support.annotation.NonNull;
import android.support.design.widget.Snackbar;
import android.support.v4.app.ActivityCompat;
import android.support.v4.app.NavUtils;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.app.AlertDialog;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.support.v7.widget.DefaultItemAnimator;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.applozic.mobicomkit.Applozic;
import com.applozic.mobicomkit.api.account.user.MobiComUserPreference;
import com.applozic.mobicomkit.api.conversation.ApplozicConversation;
import com.applozic.mobicomkit.api.conversation.ApplozicIntentService;
import com.applozic.mobicomkit.api.conversation.Message;
import com.applozic.mobicomkit.api.conversation.MessageBuilder;
import com.applozic.mobicomkit.api.conversation.MobiComConversationService;
import com.applozic.mobicomkit.api.people.UserIntentService;
import com.applozic.mobicomkit.broadcast.ConnectivityReceiver;
import com.applozic.mobicomkit.channel.database.ChannelDatabaseService;
import com.applozic.mobicomkit.channel.service.ChannelService;
import com.applozic.mobicomkit.contact.AppContactService;
import com.applozic.mobicomkit.contact.database.ContactDatabase;
import com.applozic.mobicomkit.exception.ApplozicException;
import com.applozic.mobicomkit.listners.ApplozicUIListener;
import com.applozic.mobicomkit.listners.MediaUploadProgressHandler;
import com.applozic.mobicomkit.listners.MessageListHandler;
import com.applozic.mobicommons.commons.core.utils.DateUtils;
import com.applozic.mobicommons.commons.core.utils.Utils;
import com.applozic.mobicommons.json.GsonUtils;
import com.applozic.mobicommons.people.channel.Channel;
import com.applozic.mobicommons.people.contact.Contact;
import com.devlomi.record_view.OnBasketAnimationEnd;
import com.devlomi.record_view.OnRecordClickListener;
import com.devlomi.record_view.OnRecordListener;
import com.devlomi.record_view.RecordButton;
import com.devlomi.record_view.RecordView;
import com.release.R;
//import com.release.adapters.ClickedItem;
import com.release.adapters.ConversationAdapter;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * This is an activity to show detailed conversation for any user or group.
 */
public class ConversationActivity extends AppCompatActivity implements ApplozicUIListener, ActivityCompat.OnRequestPermissionsResultCallback {

    private RecyclerView recyclerView;
    private SwipeRefreshLayout swipeRefreshLayout;
    private ConversationAdapter conversationAdapter;
    private EditText sendMessageContent;

    @Override
    public void onMqttConnected() {

    }

    @Override
    public void onUserOnline() {

    }

    @Override
    public void onUserOffline() {

    }

    @Override
    public void onUserMute(boolean mute, String userId) {

    }

    private ImageButton sendTextButton;
    private List<Message> messageList;
    private String type;
    private LinearLayout layout;
    private ImageButton sendAttachmentButton;
    private static final int REQUEST_CODE = 7;
    private static final int PICK_FILE = 4;

    private Toolbar toolbar;
    private TextView toolbarTitle;
    private TextView toolbarStatus;

    private RecordView recordView;
    private RecordButton recordButton;
    private MediaRecorder mRecorder = null;
    private static String mFileName = null;

    private LinearLayout chatBox;

    private static final String TAG = "CONVERSATION";

    private boolean isGroup = false;
    private Channel mChannel;
    private Contact mContact;

    private boolean typingStarted = false;

    private ConnectMqtt connectivityReceiver;

    /**
     * This method initializes toolbar with the name of the conversation.
     * It processes intent to open conversation with selected contact or group.
     * Swipe Refresh Layout is used to display messages so that we could load more messages on swipe.
     * It also handles sending messages and handling editText input.
     * @param savedInstanceState
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_conversation);
        toolbar = findViewById(R.id.conversation_activity_toolbar);
        toolbarTitle = findViewById(R.id.conversation_activity_toolbar_title);
        toolbarStatus = findViewById(R.id.conversation_activity_toolbar_status);
        toolbarStatus.setVisibility(View.GONE);
        setSupportActionBar(toolbar);

        connectivityReceiver = new ConnectMqtt();

        processIntent();

        getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        getSupportActionBar().setDisplayShowHomeEnabled(true);
        swipeRefreshLayout = findViewById(R.id.swipe_refresh_layout);
        layout = findViewById(R.id.footer_snackbar);
        recyclerView = findViewById(R.id.recyclerview_message_list);
        recyclerView.setHasFixedSize(true);
        LinearLayoutManager manager = new LinearLayoutManager(this);
        manager.setStackFromEnd(true);
        recyclerView.setLayoutManager(manager);
        recyclerView.setItemAnimator(new DefaultItemAnimator());
        sendMessageContent = findViewById(R.id.send_message_content);
        sendTextButton = findViewById(R.id.message_send_button);
        sendAttachmentButton = findViewById(R.id.attachment_send_button);
        recordView = (RecordView) findViewById(R.id.record_view);
        recordButton = (RecordButton) findViewById(R.id.record_button);
        chatBox = findViewById(R.id.chatbox);

        mFileName = getExternalCacheDir().getAbsolutePath();
        mFileName = mFileName +"/"+ UUID.randomUUID().toString() + "recording.amr";
        sendMessageContent.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence charSequence, int i, int i1, int i2) {

            }

            @Override
            public void onTextChanged(CharSequence charSequence, int i, int i1, int i2) {
                String val=charSequence.toString();
                changeButton(val);
            }

            @Override
            public void afterTextChanged(Editable s) {
                try {
                    if (!TextUtils.isEmpty(s.toString()) && s.toString().trim().length() > 0 && !typingStarted) {
                        typingStarted = true;
                        if (mContact != null || (mChannel != null && !Channel.GroupType.OPEN.getValue().equals(mChannel.getType()))) {
                            Applozic.publishTypingStatus(ConversationActivity.this, mChannel, mContact, true);
                        }
                    } else if (s.toString().trim().length() == 0 && typingStarted) {
                        typingStarted = false;
                        if (mContact != null || (mChannel != null && !Channel.GroupType.OPEN.getValue().equals(mChannel.getType()))) {
                            Applozic.publishTypingStatus(ConversationActivity.this, mChannel, mContact, false);
                        }
                    }

                } catch (Exception e) {

                }

            }
        });

        sendTextButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (TextUtils.isEmpty(sendMessageContent.getText().toString().trim())) {
                    Toast.makeText(ConversationActivity.this, "Empty Text", Toast.LENGTH_SHORT).show();
                } else {
                    //
                    if (type.equalsIgnoreCase("Contact")) {
                        new MessageBuilder(ConversationActivity.this).setMessage(sendMessageContent.getText().toString().trim()).setTo(mContact.getContactIds()).send();
                    } else {
                        new MessageBuilder(ConversationActivity.this).setMessage(sendMessageContent.getText().toString().trim()).setGroupId(mChannel.getKey()).send();
                    }
                }
            }
        });


        /**
         * Send attachment Open gallary to select an image
         */
        sendAttachmentButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                sendAttachment();
            }
        });

        /**
         * Pagination.
         */
        swipeRefreshLayout.setOnRefreshListener(new SwipeRefreshLayout.OnRefreshListener() {
            @Override
            public void onRefresh() {
                if(messageList.size() == 0){
                    Toast.makeText(ConversationActivity.this, "NO Conversation", Toast.LENGTH_SHORT).show();
                    swipeRefreshLayout.setRefreshing(false);
                }else {
                    if (type.equalsIgnoreCase("Contact")) {
                        Message message = messageList.get(0);
                        loadNextContactList(message);
                    } else {
                        Message message = messageList.get(0);
                        loadNextChannelList(message);
                    }
                }
            }
        });

        recordAudio();

        /**
         * Ask for permission
         */
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            showRunTimePermission();
        }
    }


    /**
     * Set the functionality of recording audio.
     * Handle view's animation
     */
    private void recordAudio(){
        //IMPORTANT
        recordButton.setRecordView(recordView);
        recordView.setOnRecordListener(new OnRecordListener() {
            @Override
            public void onStart() {
                //Start Recording..
                chatBox.setVisibility(View.INVISIBLE);
                mRecorder = new MediaRecorder();
                mRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
                mRecorder.setOutputFormat(MediaRecorder.OutputFormat.AMR_NB);
                mRecorder.setOutputFile(mFileName);
                mRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AMR_NB);
                try {
                    mRecorder.prepare();
                } catch (IOException e) {
                    Log.e(TAG+"", "prepare() failed");
                }
                mRecorder.start();
            }

            @Override
            public void onCancel() {
                //On Swipe To Cancel
                chatBox.setVisibility(View.VISIBLE);
                mRecorder.stop();
                mRecorder.release();
                mRecorder = null;
                File file = new File(mFileName);
                file.delete();
            }

            @Override
            public void onFinish(long recordTime) {
                //Stop Recording..
                String time = getHumanTimeText(recordTime);
                chatBox.setVisibility(View.VISIBLE);
                mRecorder.stop();
                mRecorder.release();
                mRecorder = null;
                if(mChannel != null)
                    sendAttachmentToGroup(mFileName);
                else
                    sendAttachmentToContact(mFileName);
            }

            @Override
            public void onLessThanSecond() {
                //When the record time is less than One Second
                chatBox.setVisibility(View.VISIBLE);
                try{
                    mRecorder.stop();
                }catch(RuntimeException stopException){
                    File file = new File(mFileName);
                    file.delete();
                    mRecorder.release();
                    mRecorder = null;
                }
            }
        });

        //ListenForRecord must be false ,otherwise onClick will not be called
        recordButton.setOnRecordClickListener(new OnRecordClickListener() {
            @Override
            public void onClick(View v) {
                Toast.makeText(ConversationActivity.this, "AUDIO RECORDING STARTED", Toast.LENGTH_SHORT).show();
            }
        });
        recordView.setOnBasketAnimationEndListener(new OnBasketAnimationEnd() {
            @Override
            public void onAnimationEnd() {
                Log.d("RecordView", "Basket Animation Finished");
            }
        });
        recordView.setCancelBounds(30);//dp
        recordView.setSmallMicColor(Color.parseColor("#c2185b"));
        recordView.setSlideToCancelText("CANCEL RECORDING");
        //disable Sounds
        recordView.setSoundEnabled(false);
        //prevent recording under one Second (it's false by default)
        recordView.setLessThanSecondAllowed(false);
        //set Custom sounds onRecord
        //you can pass 0 if you don't want to play sound in certain state
        recordView.setCustomSounds(R.raw.record_start,R.raw.record_finished,0);
    }


    /**
     * Changes Button. If user starts typing a send button will be shown otherwise record audio button will be shown.
     * @param val Indicates when user has typed or not
     */
    private void changeButton(String val){
        if (val.isEmpty())
        {
            sendTextButton.setVisibility(View.INVISIBLE);
            recordButton.setVisibility(View.VISIBLE);
        }
        else
        {
            sendTextButton.setVisibility(View.VISIBLE);
            recordButton.setVisibility(View.GONE);
        }
    }

    /**
     * Used to format the time for which recording has been done.
     * @param milliseconds the total time in milliseconds of recording.
     * @return
     */
    private String getHumanTimeText(long milliseconds) {
        return String.format("%02d:%02d",
                TimeUnit.MILLISECONDS.toMinutes(milliseconds),
                TimeUnit.MILLISECONDS.toSeconds(milliseconds) -
                        TimeUnit.MINUTES.toSeconds(TimeUnit.MILLISECONDS.toMinutes(milliseconds)));
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        processIntent();
    }

    /**
     * This method intializes variables of activity after checking if opened chat is of a contact or channel.
     * Checks intent bundle to know whether the activity has started from notification popup or from some other activity or fragment.
     * When activity is opened from some other activity or fragment, a CHECK_INTENT field is put inside intent. This is used to check if intent is from activity or notification.
     */
    private void processIntent() {
        Intent intent = getIntent();
        Bundle bundle = intent.getExtras();
        if (bundle != null) {
            if (intent.hasExtra("CHECK_INTENT")) {
                //from activity
                type = intent.getStringExtra("TYPE");
                if (type.equals("CHANNEL")) {
                    int channelId = intent.getIntExtra("ID", 12345);
                    isGroup = true;
                    getMessageListForChannel(channelId);
                } else {
                    String contactId = intent.getStringExtra("ID");
                    getMessageListForContact(contactId);
                }
            } else {
                //from notification
                Message message = (Message) GsonUtils.getObjectFromJson(intent.getStringExtra("message_json"), Message.class);
//
                if (message.isGroupMessage()) {
                    getMessageListForChannel(message.getGroupId());
                } else {
                    getMessageListForContact(message.getContactIds());
                }
            }
        }
    }

    /**
     * A setter for messageList. Also sets adapter for recycler view
     * @param messages
     */
    public void setMessageList(List<Message> messages) {
        messageList = messages;
        conversationAdapter = new ConversationAdapter(this, messageList);
        recyclerView.setAdapter(conversationAdapter);
        conversationAdapter.notifyDataSetChanged();
    }

    /**
     * Fetches messages for a contact.
     * Also sets display name of contact in the toolbar.
     * Uses ApplozicConversation.getMessageListForContact(..) method to fetch messages. createdAtTime parameter is passed as null to fetch only latest 60 messages.
     * @param contactId contact id of the opened chat. It is used to fetch contact details.
     */
    public void getMessageListForContact(String contactId) {
        final Contact contact = new AppContactService(ConversationActivity.this).getContactById(contactId);
        mContact = contact;
        if (contact != null) {
            Intent intent = new Intent(ConversationActivity.this, UserIntentService.class);
            intent.putExtra(UserIntentService.USER_ID, contactId);
            UserIntentService.enqueueWork(ConversationActivity.this, intent);
        }
        toolbarTitle.setText(contact.getDisplayName());
        Contact temp = new AppContactService(ConversationActivity.this).getContactById(mContact.getContactIds());
        toolbarStatus.setVisibility(View.VISIBLE);
        toolbarStatus.setText(temp.isOnline()?"ONLINE":"Last seen: "+DateUtils.getDateAndTimeForLastSeen(getApplicationContext(), mContact.getLastSeenAt(), R.string.JUST_NOW, R.plurals.MINUTES, R.plurals.HOURS, R.plurals.YESTERDAY));
        ApplozicConversation.getMessageListForContact(ConversationActivity.this, (new ContactDatabase(ConversationActivity.this)).getContactById(contactId), null, new MessageListHandler() {
            @Override
            public void onResult(List<Message> messageList, ApplozicException e) {
                if (e != null) {
                }
                MobiComConversationService mobiComConversationService = new MobiComConversationService(ConversationActivity.this);
                mobiComConversationService.read(contact, null);
                setMessageList(messageList);
            }
        });
    }

    /**
     * Fetches messages for a channel.
     * Also sets channel name in the toolbar.
     * Uses ApplozicConversation.getMessageListForChannel(..) method to fetch messages. createdAtTime parameter is passed as null to fetch only latest 60 messages.
     * @param channelId contact id of the opened channel. It is used to fetch channel details.
     */
    public void getMessageListForChannel(int channelId) {

        final Channel channel = ChannelService.getInstance(ConversationActivity.this).getChannelInfo(channelId);
        mChannel = channel;
        toolbarTitle.setText(channel.getName());
        ApplozicConversation.getMessageListForChannel(ConversationActivity.this, ChannelDatabaseService.getInstance(ConversationActivity.this).getChannelByChannelKey(channelId), null, new MessageListHandler() {
            @Override
            public void onResult(List<Message> messageList, ApplozicException e) {
                if (e != null) {
                }
                MobiComConversationService mobiComConversationService = new MobiComConversationService(ConversationActivity.this);
                mobiComConversationService.read(null, channel);
                setMessageList(messageList);
            }
        });
    }

    /**
     * Method is called when attachment button is pressed. It creates an intent to pick audio, video or image.
     */
    public void sendAttachment() {

        Intent takeAudioIntent = new Intent(Intent.ACTION_PICK, MediaStore.Audio.Media.EXTERNAL_CONTENT_URI);
        Intent takeVideoIntent = new Intent(Intent.ACTION_PICK, MediaStore.Video.Media.EXTERNAL_CONTENT_URI);
        Intent takePictureIntent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        Intent chooserIntent = new Intent(Intent.ACTION_CHOOSER);
        Intent contentSelectionIntent = new Intent(Intent.ACTION_GET_CONTENT);
        contentSelectionIntent.addCategory(Intent.CATEGORY_OPENABLE);
        contentSelectionIntent.setType("image/* audio/* video/*");
        Intent[] intentArray = new Intent[]{takePictureIntent,takeVideoIntent, takeAudioIntent};
        chooserIntent.putExtra(Intent.EXTRA_INTENT, contentSelectionIntent);
        chooserIntent.putExtra(Intent.EXTRA_TITLE, "Choose a file");
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentArray);
        startActivityForResult(chooserIntent, PICK_FILE);
    }

    /**
     * This method is called when activity resumes after user has selected a file to attach.
     * @param requestCode
     * @param resultCode
     * @param data
     */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PICK_FILE && resultCode == RESULT_OK && data != null) {
            Uri selectedUri = data.getData();
            String[] columns = {MediaStore.Images.Media.DATA,
                    MediaStore.Images.Media.MIME_TYPE};

            Cursor cursor1 = getContentResolver().query(selectedUri, columns, null, null, null);
            cursor1.moveToFirst();

            int pathColumnIndex = cursor1.getColumnIndex(columns[0]);
            int mimeTypeColumnIndex = cursor1.getColumnIndex(columns[1]);

            String contentPath = cursor1.getString(pathColumnIndex);
            String mimeType = cursor1.getString(mimeTypeColumnIndex);
            cursor1.close();

            String filePath = "";
            Uri selectedFile = data.getData();

            if (mimeType.startsWith("image")) {
                String filePathColumn[] = {MediaStore.Images.Media.DATA};
                filePath = getFilePathFromChoosenFile(selectedFile, filePathColumn);
            } else if (mimeType.startsWith("video")) {
                String filePathColumn[] = {MediaStore.Video.Media.DATA};
                filePath = getFilePathFromChoosenFile(selectedFile, filePathColumn);
            } else if (mimeType.startsWith("audio")) {
                String filePathColumn[] = {MediaStore.Audio.Media.DATA};
                filePath = getFilePathFromChoosenFile(selectedFile, filePathColumn);
            }

            if (type.equalsIgnoreCase("Contact")) {
                //This is a contact
                sendAttachmentToContact(filePath);
            } else {
                //This is a group
                sendAttachmentToGroup(filePath);
            }
        }
    }

    /**
     * This method returns filepath of the file selected by the user.
     * @param selectedFile File selected by user
     * @param filePathColumn audio or video or image
     * @return
     */
    private String getFilePathFromChoosenFile(Uri selectedFile, String filePathColumn[]) {
        Cursor cursor = getContentResolver().query(selectedFile, filePathColumn, null, null, null);
        cursor.moveToFirst();
        int columnIndex = cursor.getColumnIndex(filePathColumn[0]);
        String filePath = cursor.getString(columnIndex);
        cursor.close();
        return filePath;
    }

    /**
     * This method sends attachment to contact.
     * @param filePath path of the attachment to be sent
     */
    private void sendAttachmentToContact(String filePath) {
        new MessageBuilder(ConversationActivity.this)
                .setContentType(Message.ContentType.ATTACHMENT.getValue())
                .setTo(mContact.getContactIds())
                .setFilePath(filePath)
                .send(new MediaUploadProgressHandler() {

                    @Override
                    public void onUploadStarted(ApplozicException e, String oldMessageKey) {

                    }

                    @Override
                    public void onProgressUpdate(int percentage, ApplozicException e, String oldMessageKey) {

                    }

                    @Override
                    public void onCancelled(ApplozicException e, String oldMessageKey) {

                    }

                    @Override
                    public void onCompleted(ApplozicException e, String oldMessageKey) {

                    }

                    @Override
                    public void onSent(Message message, String oldMessageKey) {

                    }
                });
    }

    /**
     * This method sends attachment to group
     * @param filePath path of the attachment to be sent
     */
    private void sendAttachmentToGroup(String filePath) {
        new MessageBuilder(ConversationActivity.this)
                .setContentType(Message.ContentType.ATTACHMENT.getValue())
                .setGroupId(mChannel.getKey())
                .setFilePath(filePath)
                .send();
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
                Intent parentIntent = NavUtils.getParentActivityIntent(this);
                parentIntent.setFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                startActivity(parentIntent);
                finish();
                return true;
        }
        return super.onOptionsItemSelected(item);
    }

    /**
     * This method checks permission for writing to external storage and recording audio at runtime if device is using android version above Marshmellow.
     * This checking is done at runtime, if permission is already given nothing happens otherwise we ask for permission.
     */
    public void showRunTimePermission() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED || ActivityCompat.checkSelfPermission(this,Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) {
            requestStoragePermission();
        }
    }

    /**
     * This method asks permission for writing to external storage and recording audio at runtime.
     */
    public void requestStoragePermission() {
        final String permission[] = new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE, Manifest.permission.RECORD_AUDIO};
        ActivityCompat.requestPermissions(this, permission, REQUEST_CODE);
    }

    /**
     * This method checks if permission are granted or not and does the relevant action.
     * If permission are granted everything is resumed as normal otherwise we stop.
     * @param requestCode
     * @param permissions
     * @param grantResults
     */
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (requestCode == REQUEST_CODE) {
            if (grantResults.length > 1 && grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED) {
                Snackbar.make(layout, "permission granted", Snackbar.LENGTH_SHORT).show();
            } else {
                // permission was not granted
                if (this == null) {
                    return;
                }
                if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                        || ActivityCompat.shouldShowRequestPermissionRationale(this,Manifest.permission.RECORD_AUDIO)) {
                    finish();
                } else {
//
                    final AlertDialog.Builder alertDialogBuilder = new AlertDialog.Builder(this);
                    alertDialogBuilder.setTitle("Permissions Required")
                            .setMessage("You have forcefully denied some of the required permissions " +
                                    "for this action. Please open settings, go to permissions and allow them.")
                            .setPositiveButton("Settings", new DialogInterface.OnClickListener() {
                                @Override
                                public void onClick(DialogInterface dialog, int which) {
                                    Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", getPackageName(), null));
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                    startActivity(intent);
                                }
                            })
                            .setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
                                @Override
                                public void onClick(DialogInterface dialog, int which) {
                                    finish();
                                }
                            })
                            .setCancelable(false)
                            .create()
                            .show();
                }
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    /**
     * This method implements Pagination, load next 60 messages for a particular contact.
     * It calls onItemsLoadComplete after fetching messages.
     *
     * @param message Contains information about client id.
     */
    public void loadNextContactList(final Message message) {
        ApplozicConversation.getMessageListForContact(this, (new ContactDatabase(this)).getContactById(message.getContactIds()), messageList.get(0).getCreatedAtTime(), new MessageListHandler() {
            @Override
            public void onResult(List<Message> listMessage, ApplozicException e) {
                if (e == null) {
                    if(listMessage.size() == 0){
                        Toast.makeText(ConversationActivity.this, "No more messages to load", Toast.LENGTH_SHORT).show();
                    }
                    messageList.addAll(0, listMessage);
                    conversationAdapter.notifyItemRangeInserted(0, listMessage.size());
                    conversationAdapter.notifyItemChanged(listMessage.size());
//                    conversationAdapter.notifyDataSetChanged();
                }

                swipeRefreshLayout.setRefreshing(false);
            }
        });
    }

    /**
     * This method implements Pagination, load next 60 messages for channel.
     * It calls onItemsLoadComplete after fetching messages.
     *
     * @param message It contains information about the group.
     */
    public void loadNextChannelList(Message message) {
        ApplozicConversation.getMessageListForChannel(this, ChannelDatabaseService.getInstance(this).getChannelByChannelKey(message.getGroupId()), messageList.get(0).getCreatedAtTime(), new MessageListHandler() {
            @Override
            public void onResult(List<Message> listMessage, ApplozicException e) {
                if (e == null) {
                    if(listMessage.size() == 0){
                        Toast.makeText(ConversationActivity.this, "No more messages to load", Toast.LENGTH_SHORT).show();
                    }
                    messageList.addAll(0, listMessage);
                    conversationAdapter.notifyItemRangeInserted(0, listMessage.size());
                    conversationAdapter.notifyItemChanged(listMessage.size());
                }
                swipeRefreshLayout.setRefreshing(false);
            }
        });
    }

    /**
     * This method checks if an incoming message is for the opened conversation or not.
     * @param message Incoming message received by the broadcast.
     * @return
     */
    public boolean isMessageForAdapter(Message message) {
        if (message.isGroupMessage()) {
            if (messageList.get(0).isGroupMessage()) {
                if (message.getGroupId().equals(messageList.get(0).getGroupId())) {
                    return true;

                } else {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            if (messageList.get(0).isGroupMessage()) {
                return false;
            } else {
                if (message.getTo().equals(messageList.get(0).getTo())) {
                    return true;
                } else {
                    return false;
                }
            }
        }
    }

    /**
     * This method is used to add a new message to adapter when it is sent from device.
     * @param message This is the message sent by user
     */
    public void updateAdapterOnSent(Message message) {
        if (isMessageForAdapter(message)) {
            messageList.add(message);
            conversationAdapter.notifyDataSetChanged();
            sendMessageContent.getText().clear();
            recyclerView.scrollToPosition(messageList.size() - 1);
        }
    }

    /**
     * This method is used to update the messageList when the message is delivered to the user.
     * @param message This is the message which is delivered.
     */
    public void updateAdapterOnDelivered(Message message) {
        //check message in message list
        if(isMessageForAdapter(message)){
            int index = messageList.indexOf(message);
            if (index != -1) {
                messageList.set(index, message);
                conversationAdapter.notifyDataSetChanged();
            }
        }
    }

    /**
     * This method is used to update the delivery status of messages when participant has seen the messages.
     * @param userId userId of the conversation for which the broadcast is received.
     */
    public void updateSeenStatus(String userId) {
        if (userId.equals(messageList.get(0).getTo())) {
            for (int i = messageList.size() - 1; i >= 0; i--) {
                if (messageList.get(i).getStatus() != Message.Status.DELIVERED_AND_READ.getValue()) {
                    messageList.get(i).setStatus(Message.Status.DELIVERED_AND_READ.getValue());
                } else {
                    break;
                }
            }
            conversationAdapter.notifyDataSetChanged();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        Applozic.connectPublish(this);
        if(isGroup){
            Applozic.subscribeToTyping(ConversationActivity.this,mChannel, null);
        }else{
            Applozic.subscribeToTyping(ConversationActivity.this, null, mContact);
        }
        if(connectivityReceiver != null) {
            registerReceiver(connectivityReceiver, new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION));
        }
        Applozic.getInstance(this).registerUIListener(this);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if(isGroup){
            Applozic.unSubscribeToTyping(ConversationActivity.this,mChannel, null);
        }else{
            Applozic.unSubscribeToTyping(ConversationActivity.this, null, mContact);
        }
        if (connectivityReceiver != null) {
            unregisterReceiver(connectivityReceiver);
        }
        Applozic.disconnectPublish(this);
        Applozic.getInstance(this).unregisterUIListener();
    }


    /**
     * This method is called when messages are sent from device.
     * Also you need to set SentToServer status of message to true.
     * @param message This is the message which has just sent from device.
     */
    @Override
    public void onMessageSent(Message message) {
        Log.d("Checking ", "..................................." + "Message Sent CALLED" + "...................................");
        message.setSentToServer(true);
        updateAdapterOnDelivered(message);
    }

    /**
     * This method is called when a message has been received from the server. It adds message to messageList.
     * @param message this is the message which is just received from the server.
     */
    @Override
    public void onMessageReceived(Message message) {
        Log.d("Checking ", "..................................." + "Message Received CALLED" + "...................................");
        updateAdapterOnSent(message);
    }


    @Override
    public void onLoadMore(boolean loadMore) {
        Log.d("Checking ", "..................................." + "LOAD MORE CALLED" + "...................................");
    }

    /**
     * This method is called everytime a new message is either sent or received.
     * We can add message to messageList if the message is sent from device since received messages are already handled in onMessageReceived
     * @param message this is the new synced message
     * @param key key of the contact or group for which this new message is synced.
     */
    @Override
    public void onMessageSync(Message message, String key) {
        Log.d("Checking ", "..................................." + "Message Sync CALLED" + "...................................");
        if (message.isTypeOutbox()) {
            updateAdapterOnSent(message);
        }
    }

    @Override
    public void onMessageDeleted(String messageKey, String userId) {
        Log.d("Checking ", "..................................." + "DELETED CALLED" + "...................................");
    }

    /**
     * This method is called when message has been successfully delivered to the participant.
     * Also if message is directly delivered and read, this method is called and not the onAllMessagesRead method.
     * We can update the delivery status of message and notify the adapter.
     * @param message this is the message which is delivered.
     * @param userId
     */
    @Override
    public void onMessageDelivered(Message message, String userId) {
        Log.d("Checking ", "..................................." + "Message Delivered CALLED" + "...................................");
        updateAdapterOnDelivered(message);
    }

    @Override
    public void onAllMessagesDelivered(String userId) {
        Log.d("Checking ", "..................................." + "ALL DELIVERED CALLED" + "...................................");
    }

    /**
     * This method is called when participant of a one-to-one chat reads all the delivered messages.
     * We can update the seen status of messages from this method.
     * @param userId userId of the contact for which the read broadcast is received.
     */
    @Override
    public void onAllMessagesRead(String userId) {
        //message read
        updateSeenStatus(userId);
        Log.d("Checking ", "..................................." + "READ CALLED" + "...................................");
    }

    @Override
    public void onConversationDeleted(String userId, Integer channelKey, String response) {
        Log.d("Checking ", "..................................." + "CONVO DEL CALLED" + "...................................");
    }

    /**
     * This method is called when a user starts typing.
     * @param userId userId of the contact which has started typing
     * @param isTyping is 1 if user is typing otherwise it is 0.
     */
    @Override
    public void onUpdateTypingStatus(String userId, String isTyping) {
        if(isGroup){
            if(ChannelService.getInstance(ConversationActivity.this).isUserAlreadyPresentInChannel(mChannel.getKey(),userId)){
                if (isTyping.equals("1")) {
                    toolbarStatus.setVisibility(View.VISIBLE);
                    toolbarStatus.setText(userId+" TYPING");
                } else {
                    toolbarStatus.setText(null);
                    toolbarStatus.setVisibility(View.GONE);
                }
            }
        }else {
            if (userId.equals(mContact.getContactIds())) {
                if (isTyping.equals("1")) {
                    toolbarStatus.setVisibility(View.VISIBLE);
                    toolbarStatus.setText("TYPING.....");
                } else {
                    toolbarStatus.setText(mContact.isOnline()?"ONLINE":"Last seen: "+DateUtils.getDateAndTimeForLastSeen(getApplicationContext(), mContact.getLastSeenAt(), R.string.JUST_NOW, R.plurals.MINUTES, R.plurals.HOURS, R.plurals.YESTERDAY));
                }
            }
        }
    }

    /**
     * This method is called whenever a user has opened and left applozic chat. We can update whether user is online or not.
     * @param userId userId of the contact for which broadcast is received.
     */
    @Override
    public void onUpdateLastSeen(String userId) {
        if(!isGroup){
            if(userId.equals(mContact.getUserId())){
                Contact temp = new AppContactService(ConversationActivity.this).getContactById(userId);
                if(temp.isOnline()){
                    toolbarStatus.setVisibility(View.VISIBLE);
                    toolbarStatus.setText("ONLINE");
                }else if(temp.getLastSeenAt() != 0){
                    toolbarStatus.setVisibility(View.VISIBLE);
                    toolbarStatus.setText("Last seen: " + DateUtils.getDateAndTimeForLastSeen(getApplicationContext(), mContact.getLastSeenAt(), R.string.JUST_NOW, R.plurals.MINUTES, R.plurals.HOURS, R.plurals.YESTERDAY));
                }else{
                    toolbarStatus.setText("");
                }
            }
        }
    }

    @Override
    public void onMqttDisconnected() {
        Log.d("Checking","..................................." + "MQQQT DISCONNECTED" + "...................................");
        Applozic.connectPublish(ConversationActivity.this);
    }

    @Override
    public void onChannelUpdated() {
        Log.d("Checking ", "..................................." + "CHANNEL UPDATED CALLED" + "...................................");
    }

    @Override
    public void onConversationRead(String userId, boolean isGroup) {
        Log.d("Checking ", "..................................." + "CONVO READ CALLED" + "...................................");
    }

    @Override
    public void onUserDetailUpdated(String userId) {
        Log.d("Checking ", "..................................." + "USER DETAIL CALLED" + "...................................");
    }

    @Override
    public void onMessageMetadataUpdated(String keyString) {
        Log.d("Checking ", "..................................." + "META DATA CALLED" + "...................................");
    }

    public void connectPublishAgain(){
        Log.d("SHIVAMMM", "Chey aahiudi asida");
        Applozic.connectPublish(ConversationActivity.this);
    }

    class ConnectMqtt extends BroadcastReceiver{
        static final private String CONNECTIVITY_CHANGE = "android.net.conn.CONNECTIVITY_CHANGE";
        boolean firstConnect = true;
        @Override
        public void onReceive(@NonNull Context context, @NonNull Intent intent) {
            String action = intent.getAction();
            if (CONNECTIVITY_CHANGE.equalsIgnoreCase(action)) {
                if (!Utils.isInternetAvailable(context)) {
                    firstConnect = true;
                    return;
                }
                if (!MobiComUserPreference.getInstance(context).isLoggedIn()) {
                    return;
                }
                ConnectivityManager cm = ((ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE));
                if (cm.getActiveNetworkInfo() != null && cm.getActiveNetworkInfo().isConnected()) {
                    if (firstConnect) {
                        firstConnect = false;
                        Intent connectivityIntent = new Intent(context, ApplozicIntentService.class);
                        connectivityIntent.putExtra(ApplozicIntentService.AL_SYNC_ON_CONNECTIVITY, true);
                        ApplozicIntentService.enqueueWork(context,connectivityIntent);
                        connectPublishAgain();
                    }
                }
            }
        }
    }
}
