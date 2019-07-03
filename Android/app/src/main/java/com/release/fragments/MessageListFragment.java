package com.release.fragments;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.design.widget.FloatingActionButton;
import android.support.v4.app.Fragment;
import android.support.v4.content.LocalBroadcastManager;
import android.support.v7.widget.DefaultItemAnimator;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import com.applozic.mobicomkit.Applozic;
import com.applozic.mobicomkit.api.MobiComKitConstants;
import com.applozic.mobicomkit.api.conversation.ApplozicConversation;
import com.applozic.mobicomkit.api.conversation.Message;
import com.applozic.mobicomkit.api.conversation.database.MessageDatabaseService;
import com.applozic.mobicomkit.exception.ApplozicException;
import com.applozic.mobicomkit.listners.ApplozicUIListener;
import com.applozic.mobicomkit.listners.MessageListHandler;
import com.release.MainActivity;
import com.release.R;
import com.release.activity.MessageActivity;
import com.release.adapters.MessageRowAdapter;

import java.util.ArrayList;
import java.util.List;

public class MessageListFragment extends Fragment implements ApplozicUIListener{

    List<Message> arrayListMessageList = new ArrayList<>();

    OnFragmentInteractionListener mListener;

    //ui elements
    private FloatingActionButton floatingActionButtonAddChat;
    RecyclerView recyclerView;

    MessageRowAdapter adapter;

    private boolean loading = true;
    int pastVisibleItems, visibleItemCount, totalItemCount;
    private BroadcastReceiver unreadCountBroadcastReceiver;

    // required empty public constructor
    public MessageListFragment() { }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {

        View view = inflater.inflate(R.layout.fragment_message_list, container, false);

        recyclerView = view.findViewById(R.id.show_message_list);
        recyclerView.setHasFixedSize(true);
        final LinearLayoutManager linearLayoutManager = new LinearLayoutManager(getActivity());
        recyclerView.setLayoutManager(linearLayoutManager);
        recyclerView.setItemAnimator(new DefaultItemAnimator());

        //for pagination
        recyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrolled(RecyclerView recyclerView, int dx, int dy) {
                if(dy > 0){
                    visibleItemCount = linearLayoutManager.getChildCount();
                    pastVisibleItems = linearLayoutManager.findFirstVisibleItemPosition();
                    totalItemCount = linearLayoutManager.getItemCount();

                    if(loading){
                        if ( (visibleItemCount + pastVisibleItems) >= totalItemCount)
                        {
                            loading = false;
                            //Do pagination.. i.e. fetch new data
                            ApplozicConversation.getLatestMessageList(getActivity(), true, new MessageListHandler() {
                                @Override
                                public void onResult(List<Message> messageList, ApplozicException e) {
                                    if(e==null){
                                        arrayListMessageList.addAll(messageList);
                                        adapter.notifyDataSetChanged();
                                    }else{
                                        e.printStackTrace();
                                    }
                                }
                            });
                        }
                    }

                }
            }
        });
        unreadCountBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (MobiComKitConstants.APPLOZIC_UNREAD_COUNT.equals(intent.getAction())) {
                    int unreadCount  =  (new MessageDatabaseService(getActivity())).getTotalUnreadCount();
                    //Update unread count in UI
                }
            }
        };
        return view;
    }

    /**
     * setView is used to create the recycler view adapter from the list of messages sent to this method
     * @param messageList List of different conversation
     */
    public void setView(List<Message> messageList){
        arrayListMessageList = messageList;
        adapter = new MessageRowAdapter(getActivity(), arrayListMessageList);
        recyclerView.setAdapter(adapter);
        adapter.notifyDataSetChanged();
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);
        if (context instanceof OnFragmentInteractionListener) {
            mListener = (OnFragmentInteractionListener) context;
        } else {
            throw new RuntimeException(context.toString()
                    + " must implement OnFragmentInteractionListener");
        }
    }

    @Override
    public void onDetach() {
        super.onDetach();
        mListener = null;
    }
    @Override
    public void onResume() {
        super.onResume();
        ApplozicConversation.getLatestMessageList(getActivity(), false, new MessageListHandler() {
            @Override
            public void onResult(List<Message> messageList, ApplozicException e) {
                if(e==null){
                    setView(messageList);
                }else{
                    e.printStackTrace();
                }
            }
        });
        Applozic.connectPublish(getActivity());
        Applozic.getInstance(getActivity()).registerUIListener(this);
        LocalBroadcastManager.getInstance(getActivity()).registerReceiver(unreadCountBroadcastReceiver, new IntentFilter(MobiComKitConstants.APPLOZIC_UNREAD_COUNT));
    }

    private void changeAppBar(){
        ((MessageActivity) getActivity()).getSupportActionBar().setTitle("Chat");
    }

    @Override
    public void onPause() {
        super.onPause();
        Applozic.disconnectPublish(getActivity());
        Applozic.getInstance(getActivity()).unregisterUIListener();
        LocalBroadcastManager.getInstance(getActivity()).unregisterReceiver(unreadCountBroadcastReceiver);
     }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        super.onCreateOptionsMenu(menu, inflater);
        menu.clear();
        changeAppBar();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setHasOptionsMenu(true);
    }

    @Override
    public void onMessageSent(Message message) {
        Log.d("Attachment Sent ","Message acknowledge");
    }

    /**
     * Overridden method from ApplozicUIListener. It is called whenever a new message is received.
     * This function updates the recycler view by adding the newly received message in message list.
     * @param message The new message received.
     */
    @Override
    public void onMessageReceived(Message message) {
        Toast.makeText(getActivity(),"New Message received",Toast.LENGTH_SHORT).show();
        ApplozicConversation.addLatestMessage(message, arrayListMessageList);
        adapter.notifyDataSetChanged();
    }

    @Override
    public void onLoadMore(boolean loadMore) {
        Log.d("MyTest", "Load more called : ");
    }

    @Override
    public void onMessageSync(Message message, String key) {
        Log.d("MyTest", "Message sync finished: " + message + ", Message key : " + key);
    }

    @Override
    public void onMessageDeleted(String messageKey, String userId) {
        Log.d("MyTest", "Message deleted : " + messageKey + ", For user : " + userId);
    }

    @Override
    public void onMessageDelivered(Message message, String userId) {
        Log.d("MyTest", "Message delivered : " + message + ", For user : " + userId);
    }

    @Override
    public void onAllMessagesDelivered(String userId) {
        Log.d("MyTest", "All Messages delivered  " + " For user : " + userId);
    }

    @Override
    public void onAllMessagesRead(String userId) {
        Log.d("MyTest", "All Messages read  " + " For user : " + userId);
    }

    @Override
    public void onConversationDeleted(String userId, Integer channelKey, String response) {
        Log.d("MyTest", "Conversation deleted  " + " For user : " + userId + " For channel : " + channelKey + " with response : " + response);
    }

    @Override
    public void onUpdateTypingStatus(String userId, String isTyping) {
        Log.d("MyTest", "Typing status updated :  " + isTyping + " For user : " + userId);
    }

    @Override
    public void onUpdateLastSeen(String userId) {
        Log.d("MyTest", "Last seen updated  " + " For user : " + userId);
    }

    @Override
    public void onMqttDisconnected() {
        Log.d("MyTest", "Mqtt disconnected ");
        Applozic.connectPublish(getActivity());
    }

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
    public void onChannelUpdated() {

    }

    @Override
    public void onConversationRead(String userId, boolean isGroup) {
        Log.d("MyTest", "Conversation read for " + userId + ", isGroup : " + isGroup);
    }

    @Override
    public void onUserDetailUpdated(String userId) {
        Log.d("MyTest", "User details updated for user : " + userId);
    }

    @Override
    public void onMessageMetadataUpdated(String keyString) {

    }

    @Override
    public void onUserMute(boolean mute, String userId) {

    }

    /**
     * This interface must be implemented by activities that contain this
     * fragment to allow an interaction in this fragment to be communicated
     * to the activity and potentially other fragments contained in that
     * activity.
     * <p>
     * See the Android Training lesson <a href=
     * "http://developer.android.com/training/basics/fragments/communicating.html"
     * >Communicating with Other Fragments</a> for more information.
     */
    public interface OnFragmentInteractionListener {
        // TODO: Update argument type and name
        void onFragmentInteraction(Uri uri);
    }
}
