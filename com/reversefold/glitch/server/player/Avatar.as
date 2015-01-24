package com.reversefold.glitch.server.player {
    import com.reversefold.glitch.server.Common;
    import com.reversefold.glitch.server.Server;
    import com.reversefold.glitch.server.Utils;
    import com.reversefold.glitch.server.data.Clothing;
    import com.reversefold.glitch.server.data.Config;
    import com.reversefold.glitch.server.data.DefaultAvatars;
    import com.reversefold.glitch.server.data.Faces;
    import com.reversefold.glitch.server.data.SwfsAvatar;
    import com.reversefold.glitch.server.player.Player;
    
    import org.osmf.logging.Log;
    import org.osmf.logging.Logger;

    public class Avatar extends Common {
        private static var log : Logger = Log.getLogger("server.player.Avatar");

        public var config : Config;
        public var player : Player;

		public var clothing;
		public var a2;
        public var av_meta;

        public function Avatar(config : Config, player : Player) {
            this.config = config;
            this.player = player;
        }


public function avatar_init(){

    if (this.clothing === null || this.clothing === undefined){
        this.clothing = {};//Server.instance.apiNewOwnedDC(this);
        this.clothing.label = 'Clothing';
        this.clothing.slots = {};
    }
    if (!this.a2){
        this.a2 = {};
    }
}

public function avatar_delete_all(){

    if (this.clothing){
        this.clothing.apiDelete();
        this.clothing = null;
    }
}

public function avatar_reset(){

    this.clothing.slots = {};
    this.a2 = {};
}

////////////////////////////////////////////////////////////////

//
// change what we're wearing, passing an ID for
// each slot. we'll check both that it's a valid
// ID for clothing in that slot and that we own it.
//

public function avatar_set_clothing(map){

    this.avatar_init();

    if (!this.clothing.clothing_changes) this.clothing.clothing_changes = 0;
    this.clothing.clothing_changes++;
    this.clothing.change_time = time();

    for (var i in config.base.clothing_slots){

        if (Utils.has_key(i, map)){

            if (map[i]){
                var item = Clothing.data_clothing[map[i]];
                if (item && item.slot == i){
                    if (this.clothing_is_owned(item.slot, map[i])){
                        this.a2[i] = map[i];
                    }
                }
            }else{
                this.a2[i] = 0;
            }
        }
    }


    //
    // tell the caller what we're wearing now
    //

    var base_hash = this.avatar_base_hash();
    var sum = this.avatar_checksum(base_hash);

    return {
        'hash'      : this.avatar_hash(),
        'base_hash' : base_hash,
        'checksum'  : sum
    };
}

//
// it's the caller's resposibility to check we have permission to
// use the articles passed in (subscriber-only, admin-only, etc)
//

public function avatar_set_face(map){

    this.avatar_init();

    if (!this.clothing.face_changes) this.clothing.face_changes = 0;
    this.clothing.face_changes++;
    this.clothing.change_time = time();


    //
    // set the slot-based stuff first.
    //

    for (var i in config.base.face_slots){

        if (Utils.has_key(i, map)){

            if (map[i]){
                var item = Faces.data_faces[map[i]];
                if (item && item.slot == i){
                    this.a2[i] = map[i];
                }
            }else{
                this.a2[i] = 0;
            }
        }
    }


    //
    // the tints
    //

    if (map['hair_tint']) map['hair_color'] = map['hair_tint'];
    if (map['skin_tint']) map['skin_color'] = map['skin_tint'];

    for (var i in config.base.face_color_slots){

        if (Utils.has_key(i, map)){

            if (map[i]){
                var item = Faces.data_avatar_colors[map[i]];
                if (item && item.slot+"_color" == i){
                    this.a2[i] = map[i];
                }
            }else{
                this.a2[i] = 0;
            }
        }
    }


    //
    // the scaling params
    //

    for (var slot in config.base.face_scaling_params){

        var settings = config.base.face_scaling_params[slot];

        if (Utils.has_key(slot, map)){

            var v = floatval(map[slot]);
            if (v < settings[0]) v = settings[0];
            if (v > settings[1]) v = settings[1];

            this.a2[slot] = v;
        }
    }


    //
    // tell the caller what we're wearing now
    //

    var base_hash = this.avatar_base_hash();
    var sum = this.avatar_checksum(base_hash);

    return {
        'hash'      : this.avatar_hash(),
        'base_hash' : base_hash,
        'checksum'  : sum
    };

}

public function avatar_admin_get(){

    this.avatar_init();

    return {
        'ok'    : 1,
        'base'  : this.a2,
        'hash'  : this.avatar_hash()
    };
}

public function avatar_hash(){

    this.avatar_init();

    return this.avatar_format_hash(this.a2);
}

public function avatar_format_hash(cur){

    var out = {
        'ver'           : "01.01.11",
        'articles'      : {}
    };


    //
    // face scaling
    //

    for (var slot in config.base.face_scaling_params){

        if (cur[slot]){
            out[slot] = floatval(cur[slot]);
        }else{
            out[slot] = config.base.face_scaling_params[slot][2]; // defaults
        }
    }


    //
    // clothing items
    //

    for (var slot in config.base.clothing_slots){

        out.articles[slot] = {
            'package_swf_url'   : '',
            'article_class_name'    : 'none'
        };

        var id = cur[slot];
        if (Clothing.data_clothing[id]){

            var hash = Utils.copy_hash(Clothing.data_clothing[id]);
            var package_name = SwfsAvatar.data_swfs_avatar.assets[hash.asset];
            var package_url = SwfsAvatar.data_swfs_avatar.packages[package_name];

            if (package_url){

                hash.package_swf_url = package_url;
                delete hash.slot;
                delete hash.asset;

                out.articles[slot] = hash;
            }
        }
    }


    //
    // facial features
    //

    for (var slot in config.base.face_slots){

        out.articles[slot] = {
            'package_swf_url'   : '',
            'article_class_name'    : 'none'
        };

        var id = cur[slot];
        if (Faces.data_faces[id]){

            var hash = Utils.copy_hash(Faces.data_faces[id]);
            var package_name = SwfsAvatar.data_swfs_avatar.assets[hash.asset];
            var package_url = SwfsAvatar.data_swfs_avatar.packages[package_name];

            if (package_url){

                hash.package_swf_url = package_url;
                delete hash.slot;
                delete hash.asset;

                out.articles[slot] = hash;
            }
        }
    }


    //
    // colors
    //

    for (var slot in config.base.face_color_slots){

        // $slot contains strings like skin_color, which we need to map to skin_tint_color and skin_colors

        var old_key = slot.replace('_color', '_tint_color');
        var new_key = slot+'s';

        out[old_key] = '';
        out[new_key] = {};

        var id = cur[slot];
        if (Faces.data_avatar_colors[id]){

            out[old_key] = Faces.data_avatar_colors[id].color;
            out[new_key] = Faces.data_avatar_colors[id].colors;
        }
    }

    return out;
}

////////////////////////////////////////////////////////////////

public function clothing_admin_add_multi(args){

    var out = {};

    for (var id in args){
        out[id] = this.clothing_add(id, args[id]);
    }

    return {
        ok: 1,
        items: out
    };
}

public function clothing_add(id, info){

    var item = Clothing.data_clothing[id];
    if (!item) return false;

    this.avatar_init();

    if (!this.clothing.slots[item.slot]){
        this.clothing.slots[item.slot] = {};
    }

    this.clothing.slots[item.slot][id] = {
        'when' : time()
    };


    for (var i in info){
        this.clothing.slots[item.slot][id][i] = info[i];
    }

    return true;
}

public function clothing_is_owned(slot, id){

    this.avatar_init();

    if (!this.clothing.slots[slot]) return false;
    if (!this.clothing.slots[slot][id]) return false;

    return true;
}

public function clothing_admin_get_owned(args){

    return {
        'ok'    : 1,
        'items' : this.clothing_get_owned(args.slot)
    };
}

public function clothing_admin_get_owned_when(){

    this.avatar_init();

    var list = [];

    for (var i in this.clothing.slots){
        for (var j in this.clothing.slots[i]){
            list.push([j, this.clothing.slots[i][j]]);
        }
    }

    list.sort(function(a,b){ return a[1]-b[1] });

    var flat = {};

    for (var i=0; i<list.length; i++){
        if (typeof(list[i][1]) == 'object'){
            flat[list[i][0]] = list[i][1].when;
        } else {
            flat[list[i][0]] = list[i][1];
        }
    }

    return flat;
}

public function clothing_admin_get_recycled(){
    this.avatar_init();

    if (this.clothing.recycled){
        return this.clothing.recycled;
    } else {
        return {};
    }
}

public function clothing_expand(){

    this.avatar_init();

    for (var slot in this.clothing.slots){

        for (var id in this.clothing.slots[slot]){

            if (typeof this.clothing.slots[slot][id] != 'object'){

                this.clothing.slots[slot][id] = {
                    'when' : this.clothing.slots[slot][id]
                };
            }
        }
    }

    for (var key in this.clothing.recycled){

        if (typeof this.clothing.recycled[key] != 'object'){

            this.clothing.recycled[key] = {
                'when'      : 0,
                'id'        : key,
                'recycled'  : this.clothing.recycled[key]
            };
        }
    }
}

public function clothing_get_owned(slot){

    this.avatar_init();

    //
    // get list of [id, date] pairs
    //

    var list = [];
    var slots = Utils.copy_hash(this.clothing.slots);

    if (slot){
        if (slots[slot]){
            for (var i in slots[slot]){

                var hash = slots[slot][i];
                if (typeof hash != 'object') hash = { 'when' : hash };
                hash.id = i;
                list.push(hash);
            }
        }
    }else{
        for (var i in slots){
            for (var j in slots[i]){
                var hash = slots[i][j];
                if (typeof hash != 'object') hash = { 'when' : hash };
                hash.id = j;
                list.push(hash);
            }
        }
    }

    //
    // sort by date and flatten to IDs list
    //

    list.sort(function(a,b){ return a.when-b.when });

    return list;
}

public function clothing_admin_remove(args){

    var ret = this.clothing_remove(args.id, args.info);


    //
    // let the caller know what we're now wearing
    //

    var base_hash = this.avatar_base_hash();
    var sum = this.avatar_checksum(base_hash);

    return {
        'ok'        : 1,
        'removed'   : !!ret.ok,
        'paid_credits'  : ret.paid_credits,
        'hash'      : this.avatar_hash(),
        'base_hash' : base_hash,
        'checksum'  : sum
    };
}

public function clothing_remove(id, info){

    var item = Clothing.data_clothing[id];
    if (!item){
        return {
            ok: 0,
            error: 'item_not_found'
        };
    }

    this.avatar_init();

    if (!this.clothing.slots[item.slot]){
        return {
            ok: 0,
            error: 'not_owned'
        };
    }


    //
    // add to recycled list
    //

    if (!this.clothing.recycled){
        this.clothing.recycled = {};
    }

    var key = time();
    while ( this.clothing.recycled[key] ) key++;

    this.clothing.recycled[key] = Utils.copy_hash(this.clothing.slots[item.slot][id]);
    this.clothing.recycled[key].id = id;
    this.clothing.recycled[key].recycled = time();

    for (var i in info){
        this.clothing.recycled[key][i] = info[i];
    }


    //
    // remove from slot
    //

    var paid_credits = intval(this.clothing.slots[item.slot][id].cost_credits);

    delete this.clothing.slots[item.slot][id];


    //
    // if we were wearing it, remove it from that slot
    //

    if (this.a2[item.slot] == id){
        this.a2[item.slot] = 0;
    }

    return {
        ok: 1,
        paid_credits: paid_credits
    };
}



//
// we use this to checksum the avatar thumbnail
//

public function avatar_checksum(hash){

    var pairs = [];
    for (var i in hash){
        pairs.push(encodeURIComponent(i)+'='+encodeURIComponent(hash[i]));
    }
    pairs.sort();
    var base = pairs.join('&');

    return Server.instance.apiMD5(base);
}

public function avatar_base_hash(){

    this.avatar_init();

    return this.avatar_format_base_hash(this.a2);
}

public function avatar_format_base_hash(a){

    var keys = {
        "hat"           : 'int',
        "coat"          : 'int',
        "shirt"         : 'int',
        "pants"         : 'int',
        "dress"         : 'int',
        "skirt"         : 'int',
        "shoes"         : 'int',

        "eyes"          : 'int',
        "ears"          : 'int',
        "nose"          : 'int',
        "mouth"         : 'int',
        "hair"          : 'int',

        'skin_color'        : 'int',
        'hair_color'        : 'int',

        'eye_scale'     : 'float',
        'eye_height'        : 'float',
        'eye_dist'      : 'float',
        'ears_scale'        : 'float',
        'ears_height'       : 'float',
        'nose_scale'        : 'float',
        'nose_height'       : 'float',
        'mouth_scale'       : 'float',
        'mouth_height'      : 'float'
    };

    var out = {};

    for (var key in keys){
        var val = a[key];
        if (keys[key] == 'int') val = intval(a[key]);
        if (keys[key] == 'float') val = floatval(a[key]);
        if (keys[key] == 'string') val = str(a[key]);

        out[key] = val;
    }

    return out;
}

public function avatar_get_hashes(){

    var base_hash = this.avatar_base_hash();
    var sum = this.avatar_checksum(base_hash);

    return {
        'hash'      : this.avatar_hash(),
        'base_hash' : base_hash,
        'checksum'  : sum
    };
}

public function avatar_initial_setup(args){

    this.avatar_init();
    this.avatar_reset();


    // turn the list of owned clothes into a hash
    var clothes = {};
    for (var i in args.owned){
        clothes[args.owned[i]] = {};
    }

    // give us some clothes to own and then set clothes/face

    var r1 = this.clothing_admin_add_multi(clothes);
    var r2 = this.avatar_set_clothing(args.base);
    var r3 = this.avatar_set_face(args.base);

    this.clothing.clothing_changes = 0;
    this.clothing.face_changes = 0;

    return r3;
}

public function avatar_is_valid_facial_feature(id, slot){

    if (!id) return true;

    var item = Faces.data_faces[id];
    if (item && item.slot == slot){
        return true;
    }

    return false;
}

public function avatar_is_valid_color(id, slot){

    var item = Faces.data_avatar_colors[id];
    if (item && item.slot+'_color' == slot){
        return true;
    }

    return false;
}

public function avatar_get_pc_msg_props(){

    // props returned from this function get inserted into the 'pc' object that
    // the GS sends to the client.

    var out = {
        a2011   : this.avatar_hash()
    };

    //
    // pre-rendered
    //

    if (this.av_meta){
        out.sheet_url = this.av_meta.sheets;
        out.singles_url = this.av_meta.singles;
        out.sheet_pending = this.av_meta.pending;
    }

    return out;
}

public function avatar_set_sheets(args){
	/*
    delete this.avatar_sheets; // legacy cleanup
    delete this.avatar_pending; // legacy cleanup
	*/
    if (!this.av_meta) this.av_meta = {};

    if (args.url){
        this.av_meta.sheets = args.url;
        this.av_meta.version = args.version;
        this.av_meta.pending = false;
    }else{
        this.av_meta.pending = true;
    }

    if (Server.instance.apiIsPlayerOnline(this.player.tsid)){

        var msg = {
            'type' : 'avatar_update',
            'tsid' : this.player.tsid
        };

        var props = this.avatar_get_pc_msg_props();
        for (var i in props) msg[i] = props[i];

        this.player.location.apiSendMsg(msg);
    }

    if (args.url){
        if (this.player.buffs.buffs_has('nekkid') && !this.avatar_is_nekkid()) this.player.buffs.buffs_remove('nekkid');
        if (!this.player.buffs.buffs_has('nekkid') && this.avatar_is_nekkid()) this.player.buffs.buffs_apply('nekkid');
    }

    if (!this.apiTimerExists('buddies_update_reverse_cache')) this.apiSetTimer('buddies_update_reverse_cache', 1000);
}

public function avatar_get_singles() {
    if (this.av_meta) {
        return this.av_meta.singles;
    }
}

public function avatar_set_singles(args){

    if (!this.av_meta) this.av_meta = {};

    if (args.url){
        this.av_meta.singles = args.url;

        if (!this.apiTimerExists('buddies_update_reverse_cache')) this.apiSetTimer('buddies_update_reverse_cache', 1000);
    }
}

public function avatar_get_meta(){
    return this.av_meta;
}

public function avatar_is_nekkid(){
    var hash = this.avatar_base_hash();
    return (hash.coat + (in_array_real(hash.shirt, [553, 557, 558]) ? 0 : hash.shirt) + hash.pants + (in_array_real(hash.dress, [248, 278]) ? 0 : hash.dress) + hash.skirt > 0) ? false : true;
}

//
// this function takes a hash of clothes and returns the base_hash,
// hash and checksum for as-if we were wearing them. this is for
// rendering outfits, preset choices, etc etc
//

public function avatar_preview(args){

    this.avatar_init();

    var base = {};
    for (var i in this.a2) base[i] = this.a2[i];
    for (var i in args.a) base[i] = args.a[i];

    var hash    = this.avatar_format_hash(base);
    var base_hash   = this.avatar_format_base_hash(base);
    var checksum    = this.avatar_checksum(base_hash);

    return {
        'hash'      : hash,
        'base_hash' : base_hash,
        'checksum'  : checksum
    };
}


public function clothing_fix_state(args){

    this.avatar_init();

    // try and find this item in the currently owned clothing
    for (var slot in this.clothing.slots){
        for (var id in this.clothing.slots[slot]){

            if (id == args.id){

                for (var i in args.info){
                    this.clothing.slots[slot][id][i] = args.info[i];
                }
                return true;
            }
        }
    }

    // try and find it in the recycled items?
    for (var uid in this.clothing.recycled){

        if (this.clothing.recycled[uid].id == args.id){

            for (var i in args.info){
                this.clothing.recycled[uid][i] = args.info[i];
            }

            return true;
        }
    }

    // bah
    return false;
}


//
// this function returns a list of clothing item IDs that the player
// owns that are sub-only (and non-paid), which should be removed when
// a subscription ends
//

public function clothing_find_sub_only(){

    //
    // first build a lookup hash of everything they own,
    // excluding paid-for items and staff gifts.
    //

    var owned_hash = {};

    this.avatar_init();

    for (var slot in this.clothing.slots){
        for (var id in this.clothing.slots[slot]){

            var info = this.clothing.slots[slot][id];

            if (info.cost_credits && intval(info.cost_credits) > 0) continue;
            if (info.staff_gift) continue;

            owned_hash[id] = 1;
        }
    }


    //
    // loop through sub-only IDs, finding matches
    //

    var matches = [];

    for (var i=0; i<Clothing.data_clothing_sub_only.length; i++){

        if (owned_hash[Clothing.data_clothing_sub_only[i]]){

            matches.push(Clothing.data_clothing_sub_only[i]);
        }
    }

    return matches;
}

public function clothing_expire_sub(){

    var remove_ids = this.clothing_find_sub_only();

    var pre_sum = this.avatar_checksum(this.avatar_base_hash());

    for (var i=0; i<remove_ids.length; i++){

        var id = remove_ids[i];

        this.clothing_remove(id, {
            'sub_expired' : 1
        });
    }

    var post_sum = this.avatar_checksum(this.avatar_base_hash());


    return {
        'ok'        : 1,
        'num_removed'   : remove_ids.length,
        'avatar_update' : pre_sum == post_sum ? false : true,
        'checksum'  : post_sum
    };
}

public function avatar_admin_set_full(args){

    var r1 = this.avatar_set_clothing(args.hash);
    var r2 = this.avatar_set_face(args.hash);
    return r2;
}

public function avatar_build_default(args){

    var def = DefaultAvatars.default_avatars;

    var hash = {};
    var owned = {};

    var keys = [
        'hair_style',
        'hair_color',
        'skin_color',
        'eyes',
        'nose',
        'ears',
        'mouth',
        'top',
        'bottom',
    ];
    var ckeys = [
        'hat',
        'coat',
        'shirt',
        'dress',
        'pants',
        'skirt',
        'shoes',
    ];


    //
    // build hash
    //

    for (var i=0; i<keys.length; i++){
        var key = keys[i];
        var val = intval(args[key]);
        if (val < 0) val = 0;
        if (val > 3) val = 0;
        val = str(val);


        var bits = def[key][val];
        for (var j in bits){
            hash[j] = bits[j];
        }
    }


    //
    // build owned list
    //

    for (var i=0; i<ckeys.length; i++){
        var ckey = ckeys[i];
        var val = hash[ckey];

        if (val){
            val = str(val);
            owned[val] = val;
        }
    }


    //
    // set up avatar, return hashes
    //

    return this.avatar_initial_setup({
        'base' : hash,
        'owned' : owned
    });
}

public function avatar_default_choices(){

    var choices = DefaultAvatars.default_avatars;
    var out = {};

    for (var slot in choices){

        out[slot] = {};

        for (var idx in choices[slot]){

            var idx2 = 'choice'+idx;
            out[slot][idx2] = {
                'articles' : {}
            };

            var temp = this.avatar_format_hash(choices[slot][idx]);
            for (var i in choices[slot][idx]){

                if (temp[i]) out[slot][idx2][i] = temp[i];
                if (temp.articles[i]) out[slot][idx2].articles[i] = temp.articles[i];

                if (i == 'hair_color'){
                    out[slot][idx2].hair_tint_color = temp.hair_tint_color;
                    out[slot][idx2].hair_colors = temp.hair_colors;
                }

                if (i == 'skin_color'){
                    out[slot][idx2].skin_tint_color = temp.skin_tint_color;
                    out[slot][idx2].skin_colors = temp.skin_colors;
                }
            }
        }
    }

    return out;
}

public function avatar_admin_set_default(args){

    var hash = {};
    var code = {};

    var choices = DefaultAvatars.default_avatars;

    for (var i in choices){

        var key = args.choices[i];

        for (var j in choices[i][key]){
            hash[j] = choices[i][key][j];
        }

        code[i] = key;
    }

    this.a2 = hash;
    this.player.quickstart_needs_avatar = false;

    this.avatar_set_singles({
        'url'       : args.singles,
        'version'   : args.version
    });
    this.avatar_set_sheets({
        'url'       : args.sheets,
        'version'   : args.version
    });

    if (this.player.location.class_tsid == 'newxp_training1'){
        if (this.player.quickstart_needs_player){
            var flamingo = this.player.location.getFlamingo();
            if (flamingo){
                this.player.openInputBox('player_name_picker', 'What should we call you?', {check_user_name: true, input_max_chars: 19, cancelable: false, itemstack_tsid: flamingo.tsid, follow: true, input_label: 'What should we call you?'});
            }
        }
        else{
            this.player.location.runTutorialStep(this.player.location.getNextStep(this.player.location.current_step), null);
        }
    }
}

    }
}
