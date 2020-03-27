package com.release.adapters;

import android.content.Context;
import android.content.Intent;
import androidx.constraintlayout.widget.ConstraintLayout;
import androidx.recyclerview.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import com.applozic.mobicommons.people.contact.Contact;
import com.bumptech.glide.Glide;
import com.bumptech.glide.request.RequestOptions;
import com.release.R;
import com.release.activity.ConversationActivity;

import java.util.List;

import de.hdodenhof.circleimageview.CircleImageView;

/**
 * Created by shivam on 2/12/17.
 */

public class ContactListAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder>{

    private Context mContext;
    private LayoutInflater inflater;
    private List<Contact> contactList;

    public ContactListAdapter(Context context, List<Contact> contactList){
        mContext = context;
        inflater = LayoutInflater.from(context);
        this.contactList = contactList;
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = inflater.inflate(R.layout.contact_row,parent,false);
        MyViewHolder holder = new MyViewHolder(view);
        return holder;
    }

    /**
     * This method displays contacts in the layout.
     * On clicking any contact, conversation with that contact is opened. It passes intent to ConversationActivity with contactId.
     * @param mholder View holder
     * @param position position of current view row
     */
    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder mholder, int position) {
        MyViewHolder holder = (MyViewHolder) mholder;
        final Contact current = contactList.get(position);
        Glide.with(mContext)
                .load(current.getImageURL())
                .apply(new RequestOptions().placeholder(R.drawable.profile).error(R.drawable.profile))
                .into(holder.contactPhoto);
        holder.contactName.setText(current.getDisplayName());
        holder.contactNumber.setText(current.getContactNumber());
        holder.contactRow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Intent intent = new Intent(mContext, ConversationActivity.class);
                intent.putExtra("TYPE", "CONTACT");
                intent.putExtra("ID",current.getContactIds());
                intent.putExtra("CHECK_INTENT","ACTIVITY");
                mContext.startActivity(intent);
            }
        });
    }

    @Override
    public int getItemCount() {
        return contactList.size();
    }

    /**
     * View Holder for coversation rows. It uses message_row layout.
     */
    class MyViewHolder extends RecyclerView.ViewHolder{

        CircleImageView contactPhoto;
        TextView contactName;
        TextView contactNumber;
        ConstraintLayout contactRow;

        public MyViewHolder(View itemView) {
            super(itemView);
            contactPhoto = itemView.findViewById(R.id.contact_row_profile_image);
            contactName = itemView.findViewById(R.id.contact_row_name);
            contactNumber = itemView.findViewById(R.id.contact_row_number);
            contactRow = itemView.findViewById(R.id.contact_row);
        }
    }
}
