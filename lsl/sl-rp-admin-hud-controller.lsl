#include "config.lsl"
integer meter_chan = METER_CHAN;
string hash_seed = HASH_SEED;
key http_request_id;
string avi_uuid;
string stat_changing;
string character;
string title;
integer currency_banked = -1;
integer experience;
integer level;
integer xp_needed;
integer health;
integer attack;
integer defense;
integer dialog_listener;
integer dialog_chan;
key owner;

getAccount() {
  string params = "action=r&uuid=" + avi_uuid + "&hash=" + llSHA1String(avi_uuid + hash_seed);

  http_request_id = llHTTPRequest(API_URL,
                                  [
                                    HTTP_METHOD, "POST",
                                    HTTP_MIMETYPE, "application/x-www-form-urlencoded"
                                  ],
                                  params);
}
updateAccount(string fields) {
  string params = "uuid=" + avi_uuid + "&hash=" + llSHA1String(avi_uuid + hash_seed)
                + "&action=u" + fields;

  http_request_id = llHTTPRequest(API_URL,
                                  [
                                    HTTP_METHOD, "POST",
                                    HTTP_MIMETYPE, "application/x-www-form-urlencoded"
                                  ],
                                  params);
}
default {
  state_entry() {
    dialog_chan = (integer)llFrand(DEBUG_CHANNEL)*-1;
    owner = llGetOwner();
  }
  touch_start(integer total_number) {
    llSetTimerEvent(60);
    dialog_listener = llListen(dialog_chan, "", owner, "");
    avi_uuid = ""; stat_changing = "";
    llTextBox(owner, "\nPlayer Admin\n \nEnter the UUID of the player to lookup.", dialog_chan);
  }
  http_response(key request_id, integer status, list metadata, string body) {
    if (request_id == http_request_id) {
      if (llSubStringIndex(body, "ERR,") == 0) {
        llSay(0, "Error: " + llGetSubString(body, 4, llStringLength(body) - 1));
      } else if (llSubStringIndex(body, "STAT,") == 0) {
        if (llStringLength(stat_changing) > 0) {
          llRegionSayTo(avi_uuid, meter_chan, "1");
        }
        list fields = llCSV2List(llGetSubString(body, 5, llStringLength(body) - 1));
        character = llList2String(fields, 0);
        title = llList2String(fields, 1);
        currency_banked = llList2Integer(fields, 2);
        experience = llList2Integer(fields, 3);
        health = llList2Integer(fields, 4);
        attack = llList2Integer(fields, 5);
        defense = llList2Integer(fields, 6);
        level = llList2Integer(fields, 14);
        xp_needed = llList2Integer(fields, 15);
        string dialog_message  = "\nsecondlife:///app/agent/" + avi_uuid + "/about Stats\n "
                               + "\nCharacter: " + character
                               + "\nCurrency: " + (string)currency_banked
                               + "\nLevel: " + (string)level
                               + "\nExperience: " + (string)experience + "/" + (string)xp_needed
                               + "\nHealth: " + (string)health
                               + "\nAttack: " + (string)attack
                               + "\nDefense: " + (string)defense
                               + " \nWhich stat would you like to change?";

        dialog_listener = llListen(dialog_chan, "", owner, "");
        llSetTimerEvent(60);
        llDialog(owner, dialog_message, ["Currency", "Experience", "Health", "Attack", "Defense", "Close"], dialog_chan);
      } else {
        llSay(0, "Unexpected response: " + body);
      }
    }
  }
  listen(integer channel, string name, key id, string message) {
    if (channel == dialog_chan) {
      if (message == "Close" || llStringLength(message) == 0) { return; }
      integer len = llStringLength(avi_uuid);
      if (len == 0) {
        if (llStringLength(message) == 36) {
          avi_uuid = message;
          getAccount();
        } else if (message == "name") {
            llRegionSayTo(avi_uuid, meter_chan, "name");
        } else {
          llOwnerSay("Invalid UUID entered.");
        }
      } else if (   message == "Currency"
                 || message == "Experience"
                 || message == "Health"
                 || message == "Attack"
                 || message == "Defense"
                ) {
        stat_changing = message;
        llSetTimerEvent(60);
        dialog_listener = llListen(dialog_chan, "", owner, "");
        string dialog_message  = "\nsecondlife:///app/agent/" + avi_uuid + "/about Stats\n \n";
        llTextBox(owner, "\nsecondlife:///app/agent/" + avi_uuid + "/about Stats\n \nEnter the amount to change the " + message + ".", dialog_chan);
      } else {
        string fields = "";
        stat_changing = llToLower(stat_changing);
        if (stat_changing == "currency") {
          fields = "&currency_banked";
        } else {
          fields = "&" + stat_changing;
        }
        fields += "=" + (string)message;
        updateAccount(fields);
      }
    }
  }
  timer() {
    llListenRemove(dialog_listener);
  }
}
