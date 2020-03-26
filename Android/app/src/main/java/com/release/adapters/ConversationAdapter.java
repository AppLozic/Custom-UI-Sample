package com.release.adapters;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Handler;
import android.support.v4.app.FragmentActivity;
import android.support.v4.content.FileProvider;
import android.support.v7.widget.RecyclerView;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.MimeTypeMap;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.RelativeLayout;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import com.applozic.mobicomkit.api.attachment.FileMeta;
import com.applozic.mobicomkit.api.conversation.ApplozicConversation;
import com.applozic.mobicomkit.api.conversation.Message;
import com.applozic.mobicomkit.api.conversation.database.MessageDatabaseService;
import com.applozic.mobicomkit.channel.service.ChannelService;
import com.applozic.mobicomkit.contact.AppContactService;
import com.applozic.mobicomkit.exception.ApplozicException;
import com.applozic.mobicomkit.listners.MediaDownloadProgressHandler;
import com.applozic.mobicommons.commons.core.utils.DateUtils;
import com.applozic.mobicommons.commons.image.ImageUtils;
import com.applozic.mobicommons.people.channel.Channel;
import com.applozic.mobicommons.people.contact.Contact;
import com.bumptech.glide.Glide;
import com.bumptech.glide.request.RequestOptions;
import com.release.BuildConfig;
import com.release.R;
import com.release.Utility.PhotoFullPopupWindow;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * Created by shivam on 9/12/17.
 */

//ConversationUISERVICE

public class ConversationAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private Context mContext;
    private List<Message> messageList;
    private static final int MESSAGE_TYPE_SENT = 1;
    private static final int MESSAGE_TYPE_RECEIVED = 2;
    private boolean isImageFitToScreen;

    private static final String TAG = "CONVERSATION_ADAPTER";


    /**
     * This is the constructor used to initialize messageList.
     * @param context
     * @param messages
     */
    public ConversationAdapter(Context context, List<Message> messages) {
        this.mContext = context;
        this.messageList = messages;
    }

    /**
     * This method returns ViewHolder either SentMessageHolder or ReceivedMessageHolder
     * @param parent
     * @param viewType
     * @return SentMessageHolder if message is sent and RecievedMessageHolder if message is received.
     */
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view;
        if (viewType == MESSAGE_TYPE_SENT) {
            view = LayoutInflater.from(mContext).inflate(R.layout.sent_message_item, parent, false);
            return new SentMessageHolder(view);
        } else if (viewType == MESSAGE_TYPE_RECEIVED) {
            view = LayoutInflater.from(mContext).inflate(R.layout.received_message_item, parent, false);
            return new ReceivedMessageHolder(view);
        }
        return null;
    }

    /**
     * Display information in the recycler view depending on type of message.
     * @param mHolder
     * @param position
     */
    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder mHolder, int position) {
        final Message message = messageList.get(position);

        if(message.isTempDateType()){
        }

        switch (mHolder.getItemViewType()) {

            case MESSAGE_TYPE_SENT:
                final SentMessageHolder holder = (SentMessageHolder) mHolder;
                //clearing all visibilities
                Glide.with(mContext).clear(holder.imageViewForAttachment);
                Glide.with(mContext).clear(holder.videoViewForAttachment);
                Glide.with(mContext).clear(holder.locationViewForAttachment);
                holder.videoViewForAttachment.setVisibility(View.GONE);
                holder.imageViewForAttachment.setVisibility(View.GONE);
                holder.locationViewForAttachment.setVisibility(View.GONE);
                holder.attachmentView.setVisibility(View.GONE);
                holder.attachmentProgressText.setVisibility(View.GONE);
                holder.messageBody.setVisibility(View.GONE);
                holder.otherViewForAttachment.setVisibility(View.GONE);
                holder.audioViewForAttachment.setVisibility(View.GONE);
                holder.sendProgressBar.setVisibility(View.GONE);
                holder.overlayIcon.setVisibility(View.GONE);

                holder.messageTime.setText(DateUtils.getFormattedDate(message.getCreatedAtTime()));

                if(!message.isSentToServer()){
                    if(message.hasAttachment()) {
                        holder.sendProgressBar.bringToFront();
                        holder.sendProgressBar.setVisibility(View.VISIBLE);
                    }
                    holder.status.setImageResource(R.drawable.pending_status);
                } else {
                    if(message.hasAttachment())
                        holder.sendProgressBar.setVisibility(View.GONE);
                    if (Message.Status.READ.getValue().equals(message.getStatus()) ||
                            Message.Status.SENT.getValue().equals(message.getStatus())) {
                        holder.status.setImageResource(R.drawable.send_status);
                    } else if (Message.Status.DELIVERED_AND_READ.getValue().equals(message.getStatus())) {
                        holder.status.setImageResource(R.drawable.delivered_and_read_status);
                    } else if (Message.Status.DELIVERED.getValue().equals(message.getStatus())) {
                        holder.status.setImageResource(R.drawable.delivered_status);
                    }
                }

                if(message.hasAttachment()) {
                    holder.attachmentView.setVisibility(View.VISIBLE);
                    if (message.getFilePaths() == null) {
                        if (message.getAttachmentType().equals(Message.VIDEO)) {
                            holder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    downloadMessage(message,holder.videoViewForAttachment,holder.attachmentProgress, holder.attachmentProgressText,holder.overlayIcon);

                                    holder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            Intent intent = new Intent(Intent.ACTION_VIEW);
                                            final File file = new File(message.getFilePaths().get(0));
                                            intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                                    BuildConfig.APPLICATION_ID + ".provider",
                                                    file), "video/*");
                                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                            mContext.startActivity(intent);
                                        }
                                    });
                                }
                            });
                        } else if (message.getAttachmentType().equals(Message.AUDIO)) {
                            holder.audioViewForAttachment.setImageResource(R.drawable.attachment);
                            holder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    downloadMessage(message,holder.audioViewForAttachment,holder.attachmentProgress,holder.attachmentProgressText,holder.overlayIcon);

                                    holder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            Intent intent = new Intent();
                                            intent.setAction(android.content.Intent.ACTION_VIEW);
                                            final File file = new File(message.getFilePaths().get(0));
                                            intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                                    BuildConfig.APPLICATION_ID + ".provider",
                                                    file), "audio/*");
                                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                            mContext.startActivity(intent);
                                        }
                                    });
                                }
                            });
                        } else if (message.getAttachmentType().equals(Message.CONTACT)) {

                        } else if (message.getAttachmentType().equals(Message.LOCATION)) {

                        } else if (message.getAttachmentType().equals(Message.OTHER)) {

                        } else {
                            //image
                            holder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    downloadMessage(message,holder.imageViewForAttachment,holder.attachmentProgress,holder.attachmentProgressText,holder.overlayIcon);
                                    holder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            new PhotoFullPopupWindow(mContext, R.layout.popup_photo_full, holder.imageViewForAttachment, message.getFilePaths().get(0), null);
                                        }
                                    });
                                }
                            });
                        }
                    } else {
                        if (message.getAttachmentType().equals(Message.VIDEO)) {
                            holder.videoViewForAttachment.setVisibility(View.VISIBLE);
                            if(message.isSentToServer()) {
                                holder.overlayIcon.setVisibility(View.VISIBLE);
                                holder.overlayIcon.bringToFront();
                            }
                            final String videoPath = message.getFilePaths().get(0);
                            Glide.with(mContext)
                                    .load(Uri.fromFile(new File(videoPath)))
                                    .into(holder.videoViewForAttachment);
                            holder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    Intent intent = new Intent(Intent.ACTION_VIEW);
                                    final File file = new File(videoPath);
                                    intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                            BuildConfig.APPLICATION_ID + ".provider",
                                            file), "video/*");
                                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    mContext.startActivity(intent);
                                }
                            });
                        } else if (message.getAttachmentType().equals(Message.AUDIO)) {
                            holder.audioViewForAttachment.setVisibility(View.VISIBLE);
                            if(message.isSentToServer()) {
                                holder.overlayIcon.setVisibility(View.VISIBLE);
                                holder.overlayIcon.bringToFront();
                            }
                            final String audioPath = message.getFilePaths().get(0);
                            holder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    Intent intent = new Intent();
                                    intent.setAction(android.content.Intent.ACTION_VIEW);
                                    final File file = new File(audioPath);
                                    intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                            BuildConfig.APPLICATION_ID + ".provider",
                                            file), "audio/*");
                                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    mContext.startActivity(intent);
                                }
                            });
                        } else if (message.getAttachmentType().equals(Message.CONTACT)) {

                        } else if (message.getAttachmentType().equals(Message.LOCATION)) {

                        } else if (message.getAttachmentType().equals(Message.OTHER)) {

                        } else {
                            //image
                            holder.imageViewForAttachment.setVisibility(View.VISIBLE);
                            final String imgPath = message.getFilePaths().get(0);
                            Glide.with(mContext).load(imgPath).
                                    thumbnail(0.5f).
                                    into(holder.imageViewForAttachment);
                            holder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    new PhotoFullPopupWindow(mContext, R.layout.popup_photo_full, holder.imageViewForAttachment, imgPath, null);
                                }
                            });
                        }
                    }
                }else {
                    holder.messageBody.setVisibility(View.VISIBLE);
                    holder.messageBody.setText(message.getMessage());
                }
                break;

            case MESSAGE_TYPE_RECEIVED:
                final ReceivedMessageHolder receivedHolder = (ReceivedMessageHolder) mHolder;
                //checking attachments


                Glide.with(mContext).clear(receivedHolder.imageViewForAttachment);
                Glide.with(mContext).clear(receivedHolder.videoViewForAttachment);
                Glide.with(mContext).clear(receivedHolder.locationViewForAttachment);
                receivedHolder.videoViewForAttachment.setVisibility(View.GONE);
                receivedHolder.imageViewForAttachment.setVisibility(View.GONE);
                receivedHolder.locationViewForAttachment.setVisibility(View.GONE);
                receivedHolder.audioViewForAttachment.setVisibility(View.GONE);
                receivedHolder.attachmentView.setVisibility(View.GONE);
                receivedHolder.attachmentProgressText.setVisibility(View.GONE);
                receivedHolder.otherViewForAttachment.setVisibility(View.GONE);

                receivedHolder.overlayIcon.setVisibility(View.GONE);

                if(message.getGroupId() == null){
                    Contact contact = new AppContactService(mContext).getContactById(message.getContactIds());
                    receivedHolder.profileName.setText(contact.getDisplayName());
                }else{
                    Contact contact = new AppContactService(mContext).getContactById(message.getContactIds());
                    receivedHolder.profileName.setText(contact.getDisplayName());
                }

                receivedHolder.messageTime.setText(DateUtils.getFormattedDate(message.getCreatedAtTime()));
//                receivedHolder.profileName.setText(message.getContactIds());
                /**
                 * Download Location From Received Message.
                 */
                if(Message.ContentType.LOCATION.getValue().equals(message.getContentType())){
                    String latitude = "0";
                    String longitude = "0";
                    receivedHolder.messageBody.setVisibility(View.GONE);
                    receivedHolder.attachmentView.setVisibility(View.VISIBLE);
                    receivedHolder.locationViewForAttachment.setVisibility(View.VISIBLE);
                    try {
                        JSONObject locationObject = new JSONObject(message.getMessage());
                        latitude = locationObject.getString("lat");
                        longitude = locationObject.getString("lon");
                        //do something with this lat/long, you could load a static map.
                        String url = "http://maps.google.com/maps/api/staticmap?center=" + latitude + "," + longitude + "&zoom=15&size=200x200&sensor=false";
                        Glide.with(mContext).load(url)
                                .thumbnail(0.5f)
                                .apply(new RequestOptions()
                                .placeholder(R.drawable.location))
                                .into(receivedHolder.locationViewForAttachment);
                        final String finalLatitude = latitude;
                        final String finalLongitude = longitude;
                        receivedHolder.locationViewForAttachment.setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View view) {
                                String strUri = "http://maps.google.com/maps?q=loc:" + finalLatitude + "," + finalLongitude + " (" + "SENT_LOCATION" + ")";
                                Intent intent = new Intent(android.content.Intent.ACTION_VIEW, Uri.parse(strUri));
                                intent.setClassName("com.google.android.apps.maps", "com.google.android.maps.MapsActivity");
                                mContext.startActivity(intent);
                            }
                        });

                    } catch (JSONException e) {
                        Log.d("Latitude Exception"," Not Working");
                        e.printStackTrace();
                    }
                }

                /**
                 *Check if message has attachment
                 */
                else if (message.hasAttachment()) {
                    receivedHolder.attachmentView.setVisibility(View.VISIBLE);
                    /**
                     * If Attachment is VIDEO
                     */
                    if (message.getAttachmentType().equals(Message.VIDEO)) {
                        //VIDEO

                        String fileName = "";
                        fileName = message.getFileMetas().getName();
                        receivedHolder.messageBody.setText(fileName);
                        receivedHolder.attachmentView.setVisibility(View.VISIBLE);
                        receivedHolder.videoViewForAttachment.setVisibility(View.VISIBLE);

                        //Check if attachment is downloaded or not.
                        if(message.isAttachmentDownloaded()){
                            receivedHolder.overlayIcon.setVisibility(View.VISIBLE);
                            receivedHolder.overlayIcon.bringToFront();
                            final String videoPath = message.getFilePaths().get(0);
                            Glide.with(mContext)
                                    .load(Uri.fromFile(new File(videoPath))).apply(new RequestOptions().placeholder(R.drawable.video))
                                    .into(receivedHolder.videoViewForAttachment);
                            receivedHolder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    Intent intent = new Intent(Intent.ACTION_VIEW);
                                    final File file = new File(videoPath);
                                    intent.setDataAndType( FileProvider.getUriForFile(mContext,
                                            BuildConfig.APPLICATION_ID + ".provider",
                                            file), "video/*");
                                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    mContext.startActivity(intent);
                                }
                            });
                        }else{
                            receivedHolder.videoViewForAttachment.setVisibility(View.VISIBLE);
                            //donwload video
                            receivedHolder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    downloadMessage(message,receivedHolder.videoViewForAttachment,receivedHolder.attachmentProgress, receivedHolder.attachmentProgressText,receivedHolder.overlayIcon);
                                    receivedHolder.videoViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            Intent intent = new Intent(Intent.ACTION_VIEW);
                                            final File file = new File(message.getFilePaths().get(0));
                                            intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                                    BuildConfig.APPLICATION_ID + ".provider",
                                                    file), "video/*");
                                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                            mContext.startActivity(intent);
                                        }
                                    });
                                }
                            });

                        }
                    } else if (message.getAttachmentType().equals(Message.AUDIO)) {
                        //AUDIO

                        final String fileName = message.getFileMetas().getName();
                        receivedHolder.messageBody.setVisibility(View.GONE);
                        receivedHolder.attachmentView.setVisibility(View.VISIBLE);
                        receivedHolder.audioViewForAttachment.setVisibility(View.VISIBLE);
                        if(message.isAttachmentDownloaded()){
                            String audioPath = message.getFilePaths().get(0);
                            receivedHolder.overlayIcon.setVisibility(View.VISIBLE);
                            receivedHolder.overlayIcon.bringToFront();
                            receivedHolder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    Intent intent = new Intent();
                                    intent.setAction(android.content.Intent.ACTION_VIEW);
                                    final File file = new File(message.getFilePaths().get(0));
                                    intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                            BuildConfig.APPLICATION_ID + ".provider",
                                            file), "audio/*");
                                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    mContext.startActivity(intent);
                                }
                            });
                        }else{
                            receivedHolder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    downloadMessage(message,receivedHolder.audioViewForAttachment,receivedHolder.attachmentProgress,receivedHolder.attachmentProgressText,receivedHolder.overlayIcon);
                                    receivedHolder.audioViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            Intent intent = new Intent();
                                            intent.setAction(android.content.Intent.ACTION_VIEW);
                                            final File file = new File(message.getFilePaths().get(0));
                                            intent.setDataAndType(FileProvider.getUriForFile(mContext,
                                                    BuildConfig.APPLICATION_ID + ".provider",
                                                    file), "audio/*");
                                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                            mContext.startActivity(intent);
                                        }
                                    });
                                }
                            });
                        }
                    } else if (message.getAttachmentType().equals(Message.CONTACT)) {
//same show contacts
                    } else if (message.getAttachmentType().equals("others") || message.getAttachmentType().equals(Message.OTHER)) {
                        //ToDo Change others when issue is resolved
                        String fileName = "";
                        fileName = message.getFileMetas().getName();
                        receivedHolder.messageBody.setText(fileName);
                        receivedHolder.otherViewForAttachment.setVisibility(View.VISIBLE);

                        if(message.isAttachmentDownloaded()){
                            receivedHolder.otherViewForAttachment.setVisibility(View.VISIBLE);
                            receivedHolder.otherViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {
                                    String filePath = message.getFilePaths().get(0);
                                    File file = new File(filePath);
                                    Intent intent = new Intent();
                                    intent.setAction(Intent.ACTION_VIEW);

                                    MimeTypeMap mime = MimeTypeMap.getSingleton();
                                    String ext = file.getName().substring(file.getName().indexOf(".") + 1);
                                    String type = mime.getMimeTypeFromExtension(ext);

                                    intent.setDataAndType( FileProvider.getUriForFile(mContext,
                                            BuildConfig.APPLICATION_ID + ".provider",
                                            file), type);
                                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                    mContext.startActivity(intent);
                                }
                            });

                        }else{
                            receivedHolder.otherViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                @Override
                                public void onClick(View view) {

                                    downloadMessage(message,receivedHolder.otherViewForAttachment,receivedHolder.attachmentProgress,receivedHolder.attachmentProgressText,receivedHolder.overlayIcon);
                                    receivedHolder.otherViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                        @Override
                                        public void onClick(View view) {
                                            String filePath = message.getFilePaths().get(0);
                                            File file = new File(filePath);
                                            Intent intent = new Intent();
                                            intent.setAction(Intent.ACTION_VIEW);

                                            MimeTypeMap mime = MimeTypeMap.getSingleton();
                                            String ext = file.getName().substring(file.getName().indexOf(".") + 1);
                                            String type = mime.getMimeTypeFromExtension(ext);

                                            intent.setDataAndType( FileProvider.getUriForFile(mContext,
                                                    BuildConfig.APPLICATION_ID + ".provider",
                                                    file), type);
                                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                            mContext.startActivity(intent);
                                        }
                                    });
                                }
                            });
                        }
                    } else {

                        FileMeta fileMeta = message.getFileMetas();
                        receivedHolder.imageViewForAttachment.setVisibility(View.VISIBLE);
                        receivedHolder.attachmentView.setVisibility(View.VISIBLE);

                        if (fileMeta.getContentType().contains("image")) {
                            String fileName = "";
                            if (message.getFileMetas() == null && message.getFilePaths() != null) {
                                fileName = message.getFilePaths().get(0).substring(message.getFilePaths().get(0).lastIndexOf("/") + 1);
                            } else if (message.getFileMetas() != null) {
                                fileName = message.getFileMetas().getName();
                            }

                            receivedHolder.messageBody.setText(fileName);
                            receivedHolder.imageViewForAttachment.setVisibility(View.VISIBLE);

                            /**
                             * Check if attachment is already downloaded. If not download it.
                             */
                            if (message.isAttachmentDownloaded()) {
                                final String imgPath = message.getFilePaths().get(0);
                                Glide.with(mContext).load(imgPath).
                                        thumbnail(0.5f).
                                        into(receivedHolder.imageViewForAttachment);
                                receivedHolder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                    @Override
                                    public void onClick(View view) {
                                        new PhotoFullPopupWindow(mContext, R.layout.popup_photo_full, receivedHolder.imageViewForAttachment, imgPath, null);
                                    }
                                });

                            } else {
                                receivedHolder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                    @Override
                                    public void onClick(View view) {
                                        downloadMessage(message,receivedHolder.imageViewForAttachment,receivedHolder.attachmentProgress,receivedHolder.attachmentProgressText,receivedHolder.overlayIcon);
                                        receivedHolder.imageViewForAttachment.setOnClickListener(new View.OnClickListener() {
                                            @Override
                                            public void onClick(View view) {
                                                new PhotoFullPopupWindow(mContext, R.layout.popup_photo_full, receivedHolder.imageViewForAttachment, message.getFilePaths().get(0), null);
                                            }
                                        });
                                    }
                                });
                            }
                        }
                    }
                }else {
                    receivedHolder.messageBody.setVisibility(View.VISIBLE);
                    receivedHolder.messageBody.setText(message.getMessage());
                }
                break;
        }
    }

    /**
     * This method downloads the attachment from the server.
     * It uses ApplozicConversation.downloadMessage(..) method to handle downloading
     * @param message This is the message for which attachment is to be downloaded
     * @param view This is the imageview in which the attachment will be shown
     * @param progressBar This is the progress bar which will be displayed while the attachment is downloaded.
     * @param progressText This is the progress text which shows how much of the attachment is downloaded.
     * @param overlayIcon This is the overlay icon to be displayed on top of audios and videos to play them.
     */
    public void downloadMessage(Message message, final ImageView view, final ProgressBar progressBar, final TextView progressText,
                                final ImageButton overlayIcon){
        ApplozicConversation.downloadMessage(mContext, message, new MediaDownloadProgressHandler() {
            @Override
            public void onDownloadStarted() {
                Toast.makeText(mContext, "Downloading", Toast.LENGTH_SHORT).show();
                progressBar.setVisibility(View.VISIBLE);
                view.setVisibility(View.VISIBLE);
                view.setClickable(false);
                overlayIcon.setVisibility(View.GONE);
                progressBar.setMax(100);
                progressBar.setProgress(0);
                progressBar.setSecondaryProgress(100);
                progressBar.setProgressDrawable(mContext.getResources().getDrawable(R.drawable.circular_progress_bar));
                progressText.setVisibility(View.VISIBLE);
                progressBar.bringToFront();
                progressText.bringToFront();
            }

            @Override
            public void onProgressUpdate(int percentage, ApplozicException e) {
                progressBar.setProgress(percentage);
                progressText.setText(percentage + " %");
            }

            @Override
            public void onCompleted(Message message, ApplozicException e) {
                if(e==null && message != null){
                    progressBar.setVisibility(View.GONE);
                    progressText.setVisibility(View.GONE);
                    view.setVisibility(View.VISIBLE);
                    view.setClickable(true);
                    String path = message.getFilePaths().get(0);
                    if(message.getAttachmentType().equals(Message.VIDEO)){
                        overlayIcon.setVisibility(View.VISIBLE);
                        overlayIcon.bringToFront();
                        Glide.with(mContext).load(Uri.fromFile(new File(path))).thumbnail(0.5f).into(view);
                    }else if(message.getAttachmentType().equals("others")|| message.getAttachmentType().equals(Message.OTHER)) {

                    }else if(message.getAttachmentType().equals(Message.AUDIO)){
                        overlayIcon.setVisibility(View.VISIBLE);
                        overlayIcon.bringToFront();
                    }else{
                            Glide.with(mContext).load(path).
                                    thumbnail(0.5f).
                                    into(view);
                    }

                }
            }
        });
    }

    @Override
    public int getItemCount() {
        return messageList.size();
    }

    /**
     * This is a overriden method which is used to identify a particular message if it is a sent message or received message.
     * @param position Used to get hold of a particular message in the view.
     * @return integer value corresponding to conversation type
     *         1 : if message is sent from user
     *         2 : if message is received by user
     */
    @Override
    public int getItemViewType(int position) {
        if (messageList.get(position).isTypeOutbox()) {
            //sent message
            return MESSAGE_TYPE_SENT;
        } else {
            return MESSAGE_TYPE_RECEIVED;
        }

    }

    /**
     * ViewHolder for received message.
     * It uses received_message_item layout.
     * For Attachments we use different imageview for different attachment types which can be replaced with custom layouts
     */
    class ReceivedMessageHolder extends RecyclerView.ViewHolder {
        ImageView profileImage;
        TextView profileName;
        TextView messageBody;
        TextView messageTime;
        ImageView imageViewForAttachment;
        LinearLayout attachmentView;
        ProgressBar attachmentProgress;
        TextView attachmentProgressText;
        ImageView videoViewForAttachment;
        ImageView locationViewForAttachment;
        ImageView otherViewForAttachment;

        ImageView audioViewForAttachment;
        ImageButton overlayIcon;

        public ReceivedMessageHolder(View itemView) {
            super(itemView);
            messageBody = itemView.findViewById(R.id.message_body);
            messageTime = itemView.findViewById(R.id.message_time);
            profileImage = itemView.findViewById(R.id.profile_image);
            profileName = itemView.findViewById(R.id.profile_name);
            imageViewForAttachment = itemView.findViewById(R.id.preview);
            attachmentView = itemView.findViewById(R.id.attachment_view);
            attachmentProgress = itemView.findViewById(R.id.attachment_progress_bar);
            attachmentProgressText = itemView.findViewById(R.id.attachment_progress_bar_text);
            videoViewForAttachment = itemView.findViewById(R.id.attachment_video);
            locationViewForAttachment = itemView.findViewById(R.id.attachment_location_thumbnail);
            otherViewForAttachment = itemView.findViewById(R.id.attachment_other);

            audioViewForAttachment = itemView.findViewById(R.id.attachment_audio);
            overlayIcon = itemView.findViewById(R.id.overlay_icon);

            //setting profile
            if(messageList.get(0).getGroupId() == null){
                //contact
                Contact contact = new AppContactService(mContext).getContactById(messageList.get(0).getContactIds());
                if(contact.getImageURL() == null || contact.getImageURL().equalsIgnoreCase(null)) {
                    profileImage.setImageResource(R.drawable.profile);
                }
                else{
                    Glide.with(mContext).load(contact.getImageURL()).
                            thumbnail(0.5f).
                            apply(new RequestOptions().placeholder(R.drawable.profile)).
                            into(profileImage);
                }
            }else{
                //channel
                Channel channel = ChannelService.getInstance(mContext).getChannelInfo(messageList.get(0).getGroupId());
                if(channel.getImageUrl() == null || channel.getImageUrl().equalsIgnoreCase(null)) {
                    profileImage.setImageResource(R.drawable.group_profile);
                }
                else {
                    Glide.with(mContext).load(channel.getImageUrl()).
                            thumbnail(0.5f).
                            apply(new RequestOptions().placeholder(R.drawable.group_profile)).
                            into(profileImage);
                }
            }
        }
    }

    /**
     * ViewHolder for sent message.
     * It uses sent_message_item layout.
     * For every Attachment type we use imageview for every type which can be replaced with a custom layout.
     */
    class SentMessageHolder extends RecyclerView.ViewHolder {
        TextView messageBody;
        TextView messageTime;
        ImageView status;
        ImageView imageViewForAttachment;
        LinearLayout attachmentView;
        ProgressBar attachmentProgress;
        TextView attachmentProgressText;
        ImageView videoViewForAttachment;
        ImageView locationViewForAttachment;
        ImageView otherViewForAttachment;
        ImageView audioViewForAttachment;
        ProgressBar sendProgressBar;
        ImageButton overlayIcon;

        public SentMessageHolder(View itemView) {
            super(itemView);
            messageBody = itemView.findViewById(R.id.message_body);
            messageTime = itemView.findViewById(R.id.message_time);
            status = itemView.findViewById(R.id.delivery_status);
            imageViewForAttachment = itemView.findViewById(R.id.preview);
            attachmentView = itemView.findViewById(R.id.sender_attachment_view);
            attachmentProgress = itemView.findViewById(R.id.attachment_progress_bar);
            attachmentProgressText = itemView.findViewById(R.id.attachment_progress_bar_text);
            videoViewForAttachment = itemView.findViewById(R.id.attachment_video);
            locationViewForAttachment = itemView.findViewById(R.id.attachment_location_thumbnail);
            otherViewForAttachment = itemView.findViewById(R.id.attachment_other);

            audioViewForAttachment = itemView.findViewById(R.id.attachment_audio);
            sendProgressBar = itemView.findViewById(R.id.sending_progress_bar);
            overlayIcon = itemView.findViewById(R.id.overlay_icon);
        }
    }
}
