package com.release.activity;

import android.net.Uri;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.Toolbar;
import android.util.Log;

import com.applozic.mobicomkit.contact.database.ContactDatabase;
import com.release.R;
import com.release.adapters.ContactListAdapter;


/**
 * DISPLAY LIST OF CONTACTS
 */
public class ContactActivity extends AppCompatActivity{

    private Toolbar toolbar;
    private RecyclerView recyclerView;
    private  ContactDatabase contactDatabase;
    private ContactListAdapter contactListAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_contact);

        toolbar = (Toolbar) findViewById(R.id.contact_toolbar);
        toolbar.setTitle("Contact");
        setSupportActionBar(toolbar);
        getSupportActionBar().setDisplayHomeAsUpEnabled(true);

        recyclerView = findViewById(R.id.contact_list_recycler_view);
        LinearLayoutManager layoutManager = new LinearLayoutManager(this);
        recyclerView.setLayoutManager(layoutManager);
        recyclerView.setHasFixedSize(true);
        DividerItemDecoration dividerItemDecoration = new DividerItemDecoration(recyclerView.getContext(), layoutManager.getOrientation());
        recyclerView.addItemDecoration(dividerItemDecoration);

        contactDatabase = new ContactDatabase(this);
        contactListAdapter = new ContactListAdapter(this, contactDatabase.getAllContact());
        recyclerView.setAdapter(contactListAdapter);
        contactListAdapter.notifyDataSetChanged();

    }

}
