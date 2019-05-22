package com.release.adapters;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.applozic.mobicomkit.api.conversation.ApplozicConversation;
import com.applozic.mobicomkit.api.conversation.Message;
import com.applozic.mobicomkit.api.conversation.MobiComConversationService;
import com.applozic.mobicomkit.api.conversation.database.MessageDatabaseService;
import com.applozic.mobicomkit.channel.database.ChannelDatabaseService;
import com.applozic.mobicomkit.channel.service.ChannelService;
import com.applozic.mobicomkit.contact.AppContactService;
import com.applozic.mobicomkit.contact.database.ContactDatabase;
import com.applozic.mobicomkit.exception.ApplozicException;
import com.applozic.mobicomkit.listners.MessageListHandler;
import com.applozic.mobicommons.people.channel.Channel;
import com.applozic.mobicommons.people.contact.Contact;
import com.bumptech.glide.Glide;
import com.bumptech.glide.load.engine.DiskCacheStrategy;
import com.release.R;
import com.release.activity.ConversationActivity;

import java.util.ArrayList;
import java.util.List;

import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by shivam on 2/12/17.
 */

public class MessageRowAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder>{

    private LayoutInflater inflater;
    private Context mContext;
    private List<Message> messageList = new ArrayList<>();

    private static final int ONE_TO_ONE_CHAT = 1;
    private static final int GROUP_CHAT = 2;

    private MessageDatabaseService messageDatabaseService;

    public MessageRowAdapter(Context mContext, List<Message> listOfMessages){
        this.mContext = mContext;
        this.messageDatabaseService = new MessageDatabaseService(mContext);
        inflater = LayoutInflater.from(mContext);
        this.messageList = listOfMessages;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = inflater.inflate(R.layout.message_row,parent,false);
        MyViewHolder holder = new MyViewHolder(view);
        return holder;
    }

    /**
     * This method displays conversation header in rows displaying conversation name, image and last message.
     * It also handles onclick event on the message row opening detailed conversation with that particular thread.
     * @param mholder
     * @param position
     */
    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder mholder, int position) {
        final Message current = messageList.get(position);
        MyViewHolder holder = (MyViewHolder) mholder;
        switch (holder.getItemViewType()){
            case ONE_TO_ONE_CHAT:
                final Contact contact = new AppContactService(mContext).getContactById(current.getContactIds());
                holder.smsReceiver.setText(contact.getDisplayName());

                if(messageDatabaseService.getUnreadMessageCountForContact(current.getContactIds()) != 0){
                    holder.unreadSmsCount.setText(String.valueOf(messageDatabaseService.getUnreadMessageCountForContact(current.getContactIds())));
                }

                if(contact.getImageURL() == null || contact.getImageURL().equalsIgnoreCase(null)) {
                    holder.contactPhoto.setImageResource(R.drawable.applozic_profile_dot);
                }
                else{
                    Glide.with(mContext).load(contact.getImageURL()).
                            thumbnail(0.5f).
                            into(holder.contactPhoto);
                }
                if(current.hasAttachment()){
                    if(current.getAttachmentType().equals(Message.VIDEO)){
                        holder.message.setText("VIDEO");
                    }else if(current.getAttachmentType().equals(Message.AUDIO)){
                        holder.message.setText("AUDIO");
                    }else if(current.getAttachmentType().equals(Message.CONTACT)){
                        holder.message.setText("CONTACT");
                    }else if(current.getAttachmentType().equals(Message.LOCATION)){
                        holder.message.setText("LOCATION");
                    }else if(current.getAttachmentType().equals(Message.OTHER)){
                        holder.message.setText("ATTACHMENT");
                    }else{
                        //image
                        holder.message.setText("IMAGE");
                    }
                    holder.message.setTextColor(Color.GREEN);
                }else if(Message.ContentType.LOCATION.getValue().equals(current.getContentType())){
                    holder.message.setText("LOCATION");
                    holder.message.setTextColor(Color.MAGENTA);
                }else{
                    holder.message.setTextColor(Color.GRAY);
                    holder.message.setText(current.getMessage());
                }

                holder.createdAtTime.setText(com.applozic.mobicommons.commons.core.utils.DateUtils.
                        getFormattedDateAndTime(mContext,current.getCreatedAtTime(),R.string.JUST_NOW, R.plurals.MINUTES, R.plurals.HOURS));

                holder.singleRowLayout.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        Intent intent = new Intent(mContext, ConversationActivity.class);
                        intent.putExtra("TYPE", "CONTACT");
                        intent.putExtra("ID",current.getContactIds());
                        intent.putExtra("CHECK_INTENT","ACTIVITY");
                        mContext.startActivity(intent);
                    }
                });
                break;
            case GROUP_CHAT:

                final Channel channel = ChannelService.getInstance(mContext).getChannelInfo(current.getGroupId());
                if(channel == null)
                    break;
                holder.smsReceiver.setText(channel.getName());
//                if(channel.getUnreadCount()!=0)
//                    holder.unreadSmsCount.setText(String.valueOf(channel.getUnreadCount()));
                if(messageDatabaseService.getUnreadMessageCountForChannel(current.getGroupId()) != 0)
                    holder.unreadSmsCount.setText(String.valueOf(messageDatabaseService.getUnreadMessageCountForChannel(current.getGroupId())));
                if(channel.getImageUrl() == null || channel.getImageUrl().equalsIgnoreCase(null)) {
                    holder.contactPhoto.setImageResource(R.drawable.applozic_group_icon);
                }
                else {
                    Glide.with(mContext).load(channel.getImageUrl()).
                            thumbnail(0.5f).
                            into(holder.contactPhoto);
                }

                if(current.hasAttachment()){
                    if(current.getAttachmentType().equals(Message.VIDEO)){
                        holder.message.setText("VIDEO");
                    }else if(current.getAttachmentType().equals(Message.AUDIO)){
                        holder.message.setText("AUDIO");
                    }else if(current.getAttachmentType().equals(Message.CONTACT)){
                        holder.message.setText("CONTACT");
                    }else if(current.getAttachmentType().equals(Message.LOCATION)){
                        holder.message.setText("LOCATION");
                    }else if(current.getAttachmentType().equals(Message.OTHER)){
                        holder.message.setText("ATTACHMENT");
                    }else{
                        //image
                        holder.message.setText("IMAGE");
                    }
                    holder.message.setTextColor(Color.GREEN);
                }else if(Message.ContentType.LOCATION.getValue().equals(current.getContentType())){
                    holder.message.setText("LOCATION");
                    holder.message.setTextColor(Color.MAGENTA);
                }else{
                    holder.message.setTextColor(Color.GRAY);
                    holder.message.setText(current.getMessage());
                }

                holder.createdAtTime.setText(com.applozic.mobicommons.commons.core.utils.DateUtils.
                        getFormattedDateAndTime(mContext,current.getCreatedAtTime(),R.string.JUST_NOW, R.plurals.MINUTES, R.plurals.HOURS));

                holder.singleRowLayout.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View view) {
                        Intent intent = new Intent(mContext, ConversationActivity.class);
                        intent.putExtra("TYPE","CHANNEL");
                        intent.putExtra("ID",current.getGroupId());
                        intent.putExtra("CHECK_INTENT", "ACTIVITY");
                        mContext.startActivity(intent);
                    }
                });
                break;
        }

    }

    @Override
    public int getItemCount() {
        return messageList.size();
    }

    /**
     * This is a overriden method which is used to identify a particular row if it is a group conversation or 1-to-1 conversation.
     * @param position Used to get hold of a particular row in the view.
     * @return integer value corresponding to conversation type
     *         1 : if 1-to-1 conversation
     *         2 : if Group conversation
     */
    @Override
    public int getItemViewType(int position) {
        if(messageList.get(position).getGroupId() == null){
            return ONE_TO_ONE_CHAT;//This is a 1-to-1 message.
        }else{
            return GROUP_CHAT;//This is a Group message.
        }
    }

    /**
     * View Holder for coversation rows. It uses message_row layout.
     */
    class MyViewHolder extends RecyclerView.ViewHolder{

        ImageView contactPhoto;
        TextView smsReceiver;
        TextView createdAtTime;
        TextView message;
        TextView unreadSmsCount;
        RelativeLayout singleRowLayout;

        public MyViewHolder(View itemView) {
            super(itemView);
            contactPhoto = itemView.findViewById(R.id.contactImage);
            smsReceiver = itemView.findViewById(R.id.smsReceivers);
            createdAtTime = itemView.findViewById(R.id.createdAtTime);
            message = itemView.findViewById(R.id.message);
            unreadSmsCount = itemView.findViewById(R.id.unreadSmsCount);
            singleRowLayout = itemView.findViewById(R.id.single_row_layout);
        }
    }
}
