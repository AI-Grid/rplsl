#include "config.lsl"
string machine_name = "__ENTER_NAME_FOR_LOGGING__";
//Strided list of the format "_ITEM_NAME_", (integer)relative_weight (See notes)
list droppables = [
];
integer max_distance_from_object = 5;
integer min_level = 1;

integer cooldown_seconds = 60;
float cooldown_seconds_variation_percent = .5;

string success_msg = "After toiling and grinding, ITEM_NAME is uncovered."; //ITEM_NAME for the item received
string damage_msg = "After toiling and grinding, ITEM_NAME is uncovered. Something went wrong and you got hurt!"; //ITEM_NAME for the item received

integer health_damage_probability_percent = 75;
integer health_damage_amount = 1;
integer xp_penalty_probability_percent = 75;
integer xp_penalty_amount = 1;

string hash_seed = HASH_SEED;
integer meter_chan = METER_CHAN;
integer meter_listener;
list creators = [CREATORS];
key toucher = NULL_KEY;
key http_request_id = NULL_KEY;
integer sum;
integer num_droppables;
string received_item;

default {
  state_entry() {
    integer i;
    sum = 0;
    num_droppables = llGetListLength(droppables);
    for (i=0;i<num_droppables;i+=2) {
      sum += llList2Integer(droppables, i+1);
    }
  }
  touch_start(integer total_number) {
    if (toucher != NULL_KEY) {
      llRegionSayTo(llDetectedKey(0), 0, "Someone is currently using this drop. Please try back later.");
      return;
    }
    toucher = llDetectedKey(0);
    if (http_request_id == NULL_KEY && llVecDist(llGetPos(), llDetectedPos(0)) <= max_distance_from_object) {
      received_item = "";
      llSetTimerEvent(15);
      meter_listener = llListen(meter_chan, "", NULL_KEY, "");
      //Step 1 - Verify HUD is on
      llRegionSayTo(toucher, meter_chan, "Ping");
    } else {
      llRegionSayTo(toucher, 0, "Not close enough to touch this.");
      toucher = NULL_KEY;
    }
  }
  http_response(key request_id, integer status, list metadata, string body) {
    if (request_id == http_request_id) {
      if (llSubStringIndex(body, "ERR,") == 0) {
        if (toucher == NULL_KEY) {
          llSay(0, "Error: " + llGetSubString(body, 4, llStringLength(body) - 1));
        } else {
          llRegionSayTo(toucher, 0, "Error: " + llGetSubString(body, 4, llStringLength(body) - 1));
          toucher = NULL_KEY;llSetTimerEvent(0);
        }
      } else if (llSubStringIndex(body, "STAT,") == 0) {
        list fields = llCSV2List(llGetSubString(body, 5, llStringLength(body) - 1));
        integer experience = llList2Integer(fields, 3);
        integer level = llList2Integer(fields, 14);
        if (level < min_level) {
          llSay(0, "The minimum required level to use this device is " + (string)min_level + ".");
        }
      } else if (llSubStringIndex(body, "GIVE,") == 0) {
        //Step 4 - Give item
        string msg = success_msg;

        string params = "STAT,";

        float rand = llFrand(100);
        if (rand < (float)xp_penalty_probability_percent) {
          params += "-" + (string)xp_penalty_amount;
          msg = damage_msg;
        }
        params += ",";

        rand = llFrand(100);
        if (rand < (float)health_damage_probability_percent) {
          params += "-" + (string)health_damage_amount;
          msg = damage_msg;
        }

        if (msg == damage_msg) {
          llRegionSayTo(toucher,
                        meter_chan,
                        params + ",,,,,"
                       );
          llSetTimerEvent(15);
          meter_listener = llListen(meter_chan, "", NULL_KEY, "");
        }
        integer index;
        while ((index = llSubStringIndex(msg, "ITEM_NAME")) > -1) {
          msg = llGetSubString(msg, 0, index - 1) + received_item + llGetSubString(msg, index + 9, llStringLength(msg) - 1);
        }
        llRegionSayTo(toucher, 0, msg);
        llGiveInventory(toucher, llGetSubString(body, 5, llStringLength(body) - 1));
        llRegionSayTo(toucher, meter_chan, "1");
        toucher = NULL_KEY;llSetTimerEvent(0);
      } else if (body != "SILENT") {
        if (toucher == NULL_KEY) {
          llSay(0, "Unexpected response: " + body);
        } else {
          llRegionSayTo(toucher, 0, "Unexpected response: " + body);
          toucher = NULL_KEY;llSetTimerEvent(0);
        }
      } else {
        toucher = NULL_KEY;llSetTimerEvent(0);
      }
    }
    http_request_id = NULL_KEY;
  }
  listen(integer channel, string name, key id, string message) {
    if (channel == meter_chan) {
      if (llSubStringIndex(message, "Pong,") == 0) {
        //Step 2 - HUD validates being attached.
        llSetTimerEvent(15);
        if ((key)llGetSubString(message, 5, llStringLength(message) -1) == toucher) {
          //Step 3 - Try to give an item
          //MUST verify minimum level
          
          integer rand = llRound(llFrand(sum));
          integer i; integer running = 0;
          for (i=0;i<num_droppables;i+=2) {
            running += llList2Integer(droppables, i+1);
            if (running >= rand) {
              received_item = llList2String(droppables, i);
              string params = "uuid=" + (string)toucher + "&hash=" + llSHA1String((string)toucher + hash_seed)
                            + "&action=c"
                            + "&item=" + llEscapeURL(received_item)
                            + "&source=" + llEscapeURL(machine_name)
                            + "&min_level=" + (string)min_level
                            + "&cooldown=" + (string)((integer)((1 + llFrand(2 * cooldown_seconds_variation_percent) - cooldown_seconds_variation_percent) * cooldown_seconds));
              http_request_id = llHTTPRequest(API_URL,
                                              [
                                                HTTP_METHOD, "POST",
                                                HTTP_MIMETYPE, "application/x-www-form-urlencoded"
                                              ],
                                              params);
              return;
            }
          }
          llRegionSayTo(toucher, 0, "Did not select an object. This should not have happened.");
        }
      }
    }
  }
  timer() {
    llSetTimerEvent(0);
    llListenRemove(meter_listener);
    if (toucher != NULL_KEY) {
      if (http_request_id != NULL_KEY) {
        llRegionSayTo(toucher, 0, "Your HUD did not respond in time. You may have to detach and reattach.");
        http_request_id = NULL_KEY;
      } else {
        llSay(0, "A HUD did not respond in time. It may need to be detached and reattached.");
      }
      toucher = NULL_KEY;
    }
  }
}
