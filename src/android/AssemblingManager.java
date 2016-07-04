package com.donky.plugin;


import android.os.Bundle;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import java.util.zip.GZIPInputStream;


/**
 * @author Marcin Swierczek
 * @since 1.0.0
 * Copyright (C) Donky Networks Ltd. All rights reserved.
 */

public class AssemblingManager {

    public static final String LOG_TAG = "DonkyPlugin";

    public static final String DIRECT_NOTIFICATION_ID = "notificationId";
    public static final String DIRECT_MESSAGE_CREATED_ON = "notificationCreatedOn";
    public static final String DIRECT_MESSAGE_NOTIFICATION_TYPE = "notificationType";
    public static final String DIRECT_MESSAGE_PAYLOAD = "payload";
    public static final String DIRECT_MESSAGE_PART_BODY = "body";
    public static final String DIRECT_MESSAGE_PART_EXP_BODY = "expiredBody";
    public static final String DIRECT_MESSAGE_NOTIFICATION_TYPE_KEY = "notificationType";
    public static final String DIRECT_MESSAGE_NOTIFICATION_TYPE_RM = "RichMessage";
    public static final String DIRECT_MESSAGE_PART_TYPE = "DonkyRichMessagePart";
    public static final String BODY_KEY = "body";
    public static final String EXP_BODY_KEY = "expiredBody";
    public static final String DIRECT_MESSAGE_SEQUENCE_KEY = "sequence";
    public static final String DIRECT_MESSAGE_DATA_KEY = "data";
    public static final String DIRECT_MESSAGE_TOTAL_PARTS_KEY = "totalParts";
    public static final String DIRECT_MESSAGE_BODY_PART_COUNTS_KEY = "bodyPartCount";
    public static final String DIRECT_MESSAGE_EXP_BODY_PART_COUNTS_KEY = "expiredBodyPartCount";

    private final Map<String, MessageAssembly> assemblyMap;


    private final static Object lock = new Object();

    // Private constructor. Prevents instantiation from other classes.
    private AssemblingManager() {
        assemblyMap = new HashMap<String, MessageAssembly>();
    }

    /**
     * Initializes singleton.
     *
     * SingletonHolder is loaded on the first execution of Singleton.getInstance()
     * or the first access to SingletonHolder.INSTANCE, not before.
     */
    private static class SingletonHolder {
        private static final AssemblingManager INSTANCE = new AssemblingManager();
    }

    /**
     * Get instance of GCM Controller singleton.
     *
     * @return Instance of GCM Controller singleton.
     */
    public static AssemblingManager getInstance() {
        return SingletonHolder.INSTANCE;
    }

    /**
     * Create and store assembly object with received message parts. Try to assemble parts when all are available.
     *
     * @param bundle GCM message bundle.
     * @param isPart True if this is message part notification. False if main message notification with metadata.
     */
    Bundle assembleMessage(Bundle bundle, boolean isPart) {

        synchronized (lock) {

            if (bundle.containsKey(DIRECT_NOTIFICATION_ID)) {

                String id = bundle.getString(DIRECT_NOTIFICATION_ID);

                final String processId = "[" + UUID.randomUUID().toString() + "]: ";

                Log.v(LOG_TAG, processId + "Start assembling notification " + id);

                MessageAssembly ma = assemblyMap.get(id);

                if (ma != null) {
                    ma.missingParts -= 1;
                    Log.v(LOG_TAG, processId + "There is " + ma.missingParts + " missing parts.");
                } else {
                    ma = new MessageAssembly();
                    if (isPart) {
                        String totalParts = bundle.getString(DIRECT_MESSAGE_TOTAL_PARTS_KEY);
                        ma.missingParts = Integer.decode(totalParts);
                    } else {
                        String bodyParts = bundle.getString(DIRECT_MESSAGE_BODY_PART_COUNTS_KEY);
                        String expiredBodyParts = bundle.getString(DIRECT_MESSAGE_EXP_BODY_PART_COUNTS_KEY);
                        ma.missingParts = Integer.decode(bodyParts) + Integer.decode(expiredBodyParts);
                    }
                    Log.v(LOG_TAG, processId + "There is " + ma.missingParts + " missing parts.");
                    assemblyMap.put(id, ma);
                }

                if (isPart) {
                    String field = bundle.getString("field");
                    if (DIRECT_MESSAGE_PART_BODY.equals(field)) {
                        ma.bodyParts.add(bundle);
                        Log.v(LOG_TAG, processId + "Body part added");
                    } else if (DIRECT_MESSAGE_PART_EXP_BODY.equals(field)) {
                        ma.expiredBodyParts.add(bundle);
                        Log.v(LOG_TAG, processId + "Expired body part added");
                    }
                } else {
                    ma.mainBundle = bundle;
                    Log.v(LOG_TAG, processId + "Main bundle added");
                }

                try {
                    Bundle assembled = concatMessages(ma, id);
                    lock.notifyAll();
                    return assembled;
                } catch (JSONException e) {
                    Log.v(LOG_TAG, "Error assembling message", e);
                }
            }

            lock.notifyAll();
        }

        return null;
    }

    /**
     * If all parts can be assembled this method will remove the assembly and return the assembled message bundle.
     *
     * @param ma Message assembly to check.
     * @param id Notification id.
     * @return Assembled message bundle.
     * @throws JSONException
     */
    private Bundle concatMessages(MessageAssembly ma, String id) throws JSONException {

        if (ma.missingParts == 0 && ma.mainBundle != null) {

            Log.v(LOG_TAG, "Start concatenating standard/expired message body");

            String payload = ma.mainBundle.getString(AssemblingManager.DIRECT_MESSAGE_PAYLOAD);

            if (!TextUtils.isEmpty(payload)) {

                JSONObject jObj = new JSONObject(payload);
                String body = assembleBody(ma.bodyParts);
                String expBody = assembleBody(ma.expiredBodyParts);
                if (!TextUtils.isEmpty(body)) {
                    jObj.put(BODY_KEY, body);
                }
                if (!TextUtils.isEmpty(expBody)) {
                    jObj.put(EXP_BODY_KEY, expBody);
                }
                String stringified = jObj.toString();
                Log.v(LOG_TAG, "Payload after assembling " + stringified);
                ma.mainBundle.putString(AssemblingManager.DIRECT_MESSAGE_PAYLOAD, stringified);
                Bundle newBundle = new Bundle(ma.mainBundle);
                assemblyMap.remove(id);

                return newBundle;
            }
        }

        return null;
    }

    /**
     * Sorts message parts, adds byte arrays and decompress the resulting byte array encoded as base64 UTF-8 String.
     *
     * @param parts Parts bundles.
     * @return Message body encoded as base64 UTF-8 String.
     */
    private String assembleBody(List<Bundle> parts) {

        TreeMap<Integer, byte[]> sortedMap = new TreeMap<Integer, byte[]>();

        try {

            for (Bundle bundle : parts) {
                sortedMap.put(Integer.decode(bundle.getString(DIRECT_MESSAGE_SEQUENCE_KEY)), Base64.decode(bundle.getString(DIRECT_MESSAGE_DATA_KEY), Base64.DEFAULT));
            }

            return decompress(concatAll(sortedMap.values()));

        } catch (IOException e) {
            Log.v(LOG_TAG, "Error decompressing", e);
        }

        return null;
    }

    /**
     * Concatenates collection of byte arrays.
     *
     * @param arrays Collection of byte arrays.
     * @return
     */
    public static byte[] concatAll(Collection<byte[]> arrays) {

        int totalLength = 0;
        for (byte[] array : arrays) {
            totalLength += array.length;
        }

        byte[] result = new byte[totalLength];
        int offset = 0;

        for (byte[] array : arrays) {
            System.arraycopy(array, 0, result, offset, array.length);
            offset += array.length;
        }

        return result;
    }

    /**
     * Decompress byte array.
     */
    public static String decompress(byte[] compressed) throws IOException {

        if (compressed != null && compressed.length > 0) {

            GZIPInputStream gzipInputStream = new GZIPInputStream(
                    new ByteArrayInputStream(compressed, 0,
                            compressed.length));

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            for (int value = 0; value != -1; ) {
                value = gzipInputStream.read();
                if (value != -1) {
                    baos.write(value);
                }
            }

            gzipInputStream.close();
            baos.close();

            return new String(baos.toByteArray(), "UTF-8");

        } else {
            return null;
        }
    }

    /**
     * This method should be called by rich logic module to make sure that no redundant message assembly is being left in the memory.
     *
     * @param id Notification id.
     */
    public void removeAssembly(String id) {

        Log.v(LOG_TAG, "Removing assembly " + id);

        synchronized (lock) {
            assemblyMap.remove(id);
            lock.notifyAll();
        }

    }

    /**
     * Describes set of message parts to assemble.
     */
    class MessageAssembly {

        /**
         * Counts missing parts of the message.
         */
        int missingParts;

        /**
         * Main message bundle. Stores all the message metadata.
         */
        Bundle mainBundle;

        /**
         * Parts of expired message body.
         */
        List<Bundle> expiredBodyParts;

        /**
         * Parts of message body.
         */
        List<Bundle> bodyParts;

        MessageAssembly() {
            bodyParts = new LinkedList<Bundle>();
            expiredBodyParts = new LinkedList<Bundle>();
        }
    }
}
