package com.reversefold.glitch.server.player {
    import com.reversefold.glitch.server.Common;
    import com.reversefold.glitch.server.Server;
    import com.reversefold.glitch.server.data.Config;
    import com.reversefold.glitch.server.player.Player;
    
    import org.osmf.logging.Log;
    import org.osmf.logging.Logger;

    public class Buffs extends Common {
        private static var log : Logger = Log.getLogger("server.player.Buffs");

        public var config : Config;
        public var player : Player;
        public var skills;
		public var label;
		public var buffs;
		public var events;
		public var durations;
		public var no_no_powder_start : int;
		public var feeling_called_love_last_time : int;
		public var hairball_dash;
		public var charades_word;

        public function Buffs(config : Config, player : Player) {
            this.config = config;
            this.player = player;
        }

public function buffs_init(){

    if (!this.buffs){
        //this = apiNewOwnedDC(this);
        this.label = 'Buffs';
        this.buffs = {};
        this.events = {};
        this.durations = {};
    }
    if (!this.events){
        this.events = {};
    }
    if (!this.durations) {
        this.durations = {};
    }
}

public function buffs_delete(){
	apiDeleteTimers();
	
	this.player.buffs = new Buffs(config, player);
	/*
    if (this.buffs){
        this.apiDelete();
        delete this.buffs;
    }
	*/
}

public function buffs_reset(){

    this.buffs_init();
    this.buffs = {};
    this.events = {};
    this.durations = {};

    this.buffs_recalc_stats();
}

public function buffs_recalc_stats(){
    // TODO
}

public function buffs_login(){

    if (this.events.frozen){
        log.info(this+' unfreezing buffs');

        var diff = time() - intval(this.events.frozen);

        // shift every (online) event forward by this much

        for (var class_tsid in this.events){
            var new_events = {};
            for (var ts in this.events[class_tsid]){
                if (this.events[class_tsid][ts] == 'on'){
                    new_events[str(intval(ts) + diff)] = this.events[class_tsid][ts];
                }else{
                    new_events[str(ts)] = this.events[class_tsid][ts];
                }
            }
            this.events[class_tsid] = new_events;

            // fix buff time in the client
            if(this.buffs[class_tsid] && !this.buffs_get('timer_test').is_offline) {
                this.buffs[class_tsid].start += diff;

                var out = {
                    type: 'buff_update',
                    tsid: class_tsid,
                    duration: this.buffs[class_tsid].duration,
                    remaining_duration: this.buffs[class_tsid].duration - (time() - this.buffs[class_tsid].start)
                };
                this.apiSendMsg(out);
            }
        }

        delete this.events.frozen;
        this.buffs_fire_timer();

        //
        // reset timers for "you did X for Y long" achievements
        //
        if (this.no_no_powder_start){
            this.no_no_powder_start = time();
        }
    }

    // Fix time on buffs that have been extended.
    var durations_list = this.durations;
    if (durations_list) {
        for (var tsid in durations_list) {
            if (this.buffs_has(tsid)) {
                var buff = this.buffs_get_instance(tsid);

                var out = {
                    type: 'buff_update',
                    tsid: tsid,
                    duration: durations_list[tsid],
                    remaining_duration: durations_list[tsid] - (time() - buff.args.start)
                };
                this.player.sendMsgOnline(out);
            }
            else {
                delete this.durations[tsid];
            }
        }
    }
}

public function buffs_logout(){
    if (this.buffs && this.events){
        log.info(this+' freezing buffs');
        this.events.frozen = time();
    }
}

public function buffs_apply_delay(class_tsid, args, seconds){
    this.player.events.events_add({callback: 'buffs_on_apply_delay', class_tsid: class_tsid, args: args}, seconds);
}

public function buffs_on_apply_delay(details){
    this.buffs_apply(details.class_tsid, details.args);
}

public function buffs_apply(class_tsid, args=null){

    //
    // get buff info
    //

    var buff = this.buffs_get(class_tsid);
    if (!buff) return;


    //
    // Restart this buff if it exists
    //

    if (this.buffs_has(class_tsid)){
        this.buffs_remove_client(class_tsid);
        delete this.events[class_tsid];
        delete this.buffs[class_tsid];
        if (this.durations) delete this.durations[class_tsid];
    }


    //
    // remove buffs in the same group
    //

    // TODO


    //
    // get info
    //

    if (!args) args = {};
    if (!args.duration) args.duration = buff.duration;
    if (!args.tick_duration) args.tick_duration = buff.tick_duration;
    args.start = time();
    args.ticks_elapsed = 0;

    // if we have a tick of 5 seconds and it's an 11 second buff, it's really a 10 second buff

    var events = [];

    if (args.duration && args.tick_duration){

        if (!args.ticks){
            args.ticks = Math.floor(args.duration / args.tick_duration);
        }
        args.duration = args.tick_duration * args.ticks;

        for (var i=1; i<=args.ticks; i++){
            events.push(args.start + (i * args.tick_duration));
        }

    }else if (args.tick_duration){
        //log.info('Buff ' + class_tsid + ' ticks forever. First tick at: ' + (args.start + args.tick_duration));
        events.push(args.start + args.tick_duration);
        args.ticks = 1;

    }else{
        events.push(args.start + args.duration);
    }


    //
    // store
    //

    this.buffs[class_tsid] = args;
    this.buffs_add_events(events, class_tsid, buff.is_offline);

    this.buffs_fire_apply(class_tsid);

    Server.instance.apiLogAction('BUFF_APPLIED', 'pc='+this.player.tsid, 'buff='+class_tsid);


    // Achievement check:
    if (this.player.location.pols_is_pol() && !this.player.location.is_public) {
        this.player.location.checkEpicBlowout();
    }
}

public function buffs_remove(class_tsid){
    if(!this.buffs_has(class_tsid)) {
        log.info("Error: attempted to remove buff "+class_tsid+" from player "+this+", but player does not have the buff!");
        return;
    }

    //log.info('buffs_remove for '+class_tsid);
    this.buffs_fire_remove(class_tsid);

    delete this.events[class_tsid];
    delete this.buffs[class_tsid];
    if (this.durations) delete this.durations[class_tsid];
    this.player.stats.stats_fixup_buffs();

    Server.instance.apiLogAction('BUFF_REMOVED', 'pc='+this.player.tsid, 'buff='+class_tsid);
}

public function buffs_remove_all(){
    var buffs = this.buffs_get_active();

    for (var i in buffs){
        this.buffs_remove(i);
    }
}

public function buffs_get(class_tsid){

    var prot = Server.instance.apiFindItemPrototype('catalog_buffs');
    return prot.buffs[class_tsid];
}


//
// buffs all share a single timer. for this to work, each
// pc has a list of upcoming events for all buffs. we set
// a timer for the next upcoming event and then dispatch
// as needed
//

public function buffs_add_events(events, class_tsid, is_offline){
    //log.info('buffs_add_events: '+class_tsid);

    this.events[class_tsid] = {};

    for (var i=0; i<events.length; i++){
        this.events[class_tsid][str(events[i])] = is_offline ? 'off' : 'on';
    }

    this.buffs_fire_timer();
}

public function buffs_fire_timer(){

//  log.info(this+' [buffs] calling buffs_fire_timer() -------------------------------------------------------------***');


    //
    // find the next time that needs to be fired (and fire anything that's already passed)
    //

    var now = time();

    for (var class_tsid in this.events){
        //log.info(this+' [buffs] timer class '+class_tsid);

        for (var ts in this.events[class_tsid]){

            //log.info(this+' [buffs] timer ts '+ts);

            //
            // skip online timers if we're frozen
            //

            if (this.events.frozen && this.events[class_tsid][ts] == 'on') continue;

            var tsi = intval(ts);

            //
            // this buff needs to fire right now
            //

            if (tsi <= now){

                //
                // does this buff need to tick forever?
                //

                var buff = this.buffs_get_instance(class_tsid);
                if (buff.args.tick_duration && !buff.args.duration){

                    //log.info('Buff ' + class_tsid + ' is infinite. Scheduling another tick for: ' + (tsi + buff.args.tick_duration));

                    var next_tsi = tsi + buff.args.tick_duration;
                    if (next_tsi < now) next_tsi = now;
                    this.events[class_tsid][str(next_tsi)] = this.events[class_tsid][ts];
                }

                if (this.buffs[class_tsid].ticks){

                    //log.info(this+' [buffs] ================== running event '+ts);

                    this.buffs[class_tsid].ticks_elapsed++;
                    this.buffs_fire_tick(class_tsid);
                }

                //
                // It's possible for the buff to have been removed during the tick
                //

                if (!this.events[class_tsid]) continue;

                delete this.events[class_tsid][ts];

                //log.info('removing event '+ts+' from the run list');

                if ((buff.args.duration || buff.args.tick_duration) && !num_keys(this.events[class_tsid])){

                    //log.info('Removing buff ' + class_tsid);
                    this.buffs_remove(class_tsid);
                }
            }
        }
    }


    //
    // do we need to set any future timers?
    //

    var next = this.buffs_get_next_event_tsi();
    if (next){
        this.apiCancelTimer('buffs_fire_timer');
        var away = next - now;
        if (away <= 0) away = 0.1;
        var timer = away * 1000;

//      log.info(this+' [buffs] it is now '+now+' and next is '+next);
//      log.info(this+' [buffs] setting timer for '+away+' seconds from now ('+timer+')');
        this.apiSetTimer('buffs_fire_timer', timer);
    }
}

public function buffs_get_next_event_tsi(){
    var next = 0;

    for (var class_tsid in this.events){
        for (var ts in this.events[class_tsid]){

            //
            // skip online timers if we're frozen
            //

            if (this.events.frozen && this.events[class_tsid][ts] == 'on') continue;

            var tsi = intval(ts);

            if (next == 0 || tsi < next){
                next = tsi;
            }
        }
    }

    return next;
}

public function buffs_get_instance(class_tsid){

    return {
        'class_tsid'    : class_tsid,
        'def'       : this.buffs_get(class_tsid),
        'args'      : this.buffs[class_tsid],
        'duration'  : this.durations ? this.durations[class_tsid] : 0,
        'pc'        : this,
        'addStat'   : function (stat_id, value){ this.pc.stats_set_temp_buff(this.class_tsid, stat_id, value); }
    };
}

// Extend the time on a buff that is already applied to the player. Works for ticking buffs and non-ticking buffs.
public function buffs_extend_time(class_tsid, amount) {
    var result_amount = amount;
    var buff = this.buffs_get_instance(class_tsid);

    if(!buff) {
        throw "Error: attempt to extend non-existent buff.";
    }

    var tick_duration = buff.args ? buff.args.tick_duration : 0;

    if (tick_duration) {

        var stored_duration = buff.args.duration;
        if (this.durations[class_tsid]) {
            stored_duration = this.durations[class_tsid];
        }

        var ticks = Math.floor(stored_duration / tick_duration);
        var duration = tick_duration * ticks;

        var last_tick_time = buff.args.start + duration;

        var ticks_to_add = Math.floor(amount / tick_duration);
        var duration_to_add = tick_duration * ticks_to_add;

        var events = [];

        // Start with the old events:
        var old_events = this.events[class_tsid];
        for (var e in old_events) {
            events.push(e);
        }

        // Add additional tick events:
        for (var i=1; i<=ticks_to_add; i++){
            events.push(last_tick_time + (i * tick_duration));
        }

        this.buffs_add_events(events, class_tsid, buff.is_offline);
    }
    else {
        var duration = buff.duration ? buff.duration : buff.args.duration;
        var duration_to_add = amount;
    }

    var new_duration = duration + duration_to_add;

    this.durations[class_tsid] = new_duration;

    var out = {
        type: 'buff_update',
        tsid: class_tsid,
        duration: new_duration,
        remaining_duration: new_duration - (time() - buff.args.start)
    };
    this.player.sendMsgOnline(out);
}

public function buffs_alter_time(class_tsid, amount, duration) {
    var result_amount = amount;
    var buff = this.buffs_get_instance(class_tsid);

    if(!buff) {
        throw "Error: attempt to alter non-existent buff.";
    }

    // Don't support ticking buffs. Just abort with error.
    if(buff.args.tick_duration) {
        throw "Error: buffs_alter_time does not yet support buffs with tick durations.";
    }

    var dur = duration ? duration : buff.args.duration;

    // Is the buff already expired now? If so, remove it.
    if(buff.args.start + dur + amount < time()) {
        this.buffs_remove(class_tsid);
        return;
    }

    // Adjust buff finish time by adjusting the start time
    buff.args.start += amount;
    // If the buff now hasn't started yet, move the start time to now.
    if(buff.args.start > time()) {
        result_amount = amount + (time() - buff.args.start);
        buff.args.start = time();
        amount = 0;
    }

    // Now reschedule the buff ending
    if(this.events[class_tsid]) {
        delete this.events[class_tsid];
        var events = [buff.args.start + dur];
        this.buffs_add_events(events, class_tsid, buff.def.is_offline)
    }

    // otherwise, we should be good. Post a new message to the client updating the time.
    var out = {
        type: 'buff_update',
        tsid: class_tsid,
        duration: dur,
        remaining_duration: dur - (time() - buff.args.start)
    };
    this.player.sendMsgOnline(out);

    return result_amount;
}

public function buffs_fire_apply(class_tsid){

    //log.info('buffs_fire_apply: '+class_tsid);

    try{
        var buff = this.buffs_get_instance(class_tsid);
        if (!buff.args){
            log.error(this+" buffs_fire_apply missing args "+class_tsid+": ", buff);
        }

        //this.sendActivity('Starting a buff: '+buff.def.name+' (Last for '+buff.args.duration+'s)');
        var out = {
            type: 'buff_start',
            tsid: class_tsid,
            name: buff.def.name,
            desc: buff.def.desc,
            duration: buff.args.duration,
            ticks: buff.args.ticks,
            is_timer: buff.def.is_timer || this.buffs_has('admin_buff_timers'),
            is_debuff: buff.def.is_debuff,
            item_class: buff.def.item_class
        };

        //log.info('APPLY', out);
        this.player.sendMsgOnline(out);
        this.player.events.events_add({out: out, callback: 'buffs_perform_postprocessing'}, 0.1);

        buff.def.on_apply.call(buff, this, this.buffs[class_tsid]);
    }
    catch (e){
        log.error(this+" Error applying buff "+class_tsid+": ", e);
    }
}

public function buffs_fire_tick(class_tsid){
    //log.info('buffs_fire_tick: '+class_tsid);

    try {
        var buff = this.buffs_get_instance(class_tsid);

        //this.sendActivity('Ticking a buff: '+buff.def.name);
        // This apparently does nothing. The client now ignores buff tick messages.
/*      var out = {
            type: 'buff_tick',
            tsid: class_tsid,
            name: buff.def.name,
            desc: buff.def.desc,
            duration: buff.args.duration,
            ticks: buff.args.ticks,
            ticks_elapsed: intval(buff.args.ticks_elapsed)
        };

        //log.info('TICK', out);
        this.player.sendMsgOnline(out);
        this.events_add({out: out, callback: 'buffs_perform_postprocessing'}, 0.1);*/

        buff.def.on_tick.call(buff, this, this.buffs[class_tsid]);
    }
    catch (e){
        log.error("Error ticking buff", e);
    }
}

public function buffs_fire_remove(class_tsid){
    //log.info('buffs_fire_remove: '+class_tsid);

    try {
        var buff = this.buffs_get_instance(class_tsid);

        this.buffs_remove_client(class_tsid);

        buff.def.on_remove.call(buff, this, this.buffs[class_tsid]);

        if (this.durations && this.durations[class_tsid]) {
            delete this.durations[class_tsid];
        }
    }
    catch (e){
        log.error("Error removing buff", e);
    }
}

public function buffs_remove_client(class_tsid){
    var buff = this.buffs_get_instance(class_tsid);

    //this.sendActivity('Removing a buff: '+buff.def.name);
    var out = {
        type: 'buff_remove',
        tsid: class_tsid,
        name: buff.def.name,
        desc: buff.def.desc
    };

    //log.info('REMOVE', out);
    this.player.sendMsgOnline(out);
    this.player.events.events_add({out: out, callback: 'buffs_perform_postprocessing'}, 0.1);
}

public function buffs_perform_postprocessing(details){
    if (!details.out) return;

    this.player.performPostProcessing(details.out);
}

public function buffs_has(class_tsid){

    if (!this.buffs) return 0;
    return (this.buffs[class_tsid]) ? 1 : 0;
}

public function buffs_get_active(){
    var buffs = {};
    for (var class_tsid in this.events){
        var buff = this.buffs_get_instance(class_tsid);

        if (buff && buff.def){
            buffs[class_tsid] = {
                name: buff.def.name,
                desc: buff.def.desc,
                duration: buff.args.duration,
                ticks: buff.args.ticks,
                ticks_elapsed: intval(buff.args.ticks_elapsed),
                is_timer: buff.def.is_timer || this.buffs_has('admin_buff_timers'),
                is_debuff: buff.def.is_debuff,
                item_class: buff.def.item_class,
                remaining_duration: this.buffs_get_remaining_duration(class_tsid)
            };
        }
    }

    return buffs;
}

public function buffs_get_remaining_duration(class_tsid){
    var buff = this.buffs_get_instance(class_tsid);

    if (!buff.args.duration) return 0; // buff ticks forever

    if (this.events[class_tsid]){
        //
        // Find the maximum event for this buff. That must be the end!
        //

        var max_tsi = 0;
        for (var ts in this.events[class_tsid]){
            var tsi = intval(ts);
            if (tsi > max_tsi) max_tsi = tsi;
        }

        if (!max_tsi || max_tsi < time()) return 0;
        return max_tsi - time();
    }

    return 0;
}

public function buffs_transfer_love(pc){
    var now = time();
    if (now - this.feeling_called_love_last_time > 2) {
        if (!pc.feeling_called_love_last_time || (now - pc.feeling_called_love_last_time > 45)){

            pc.buffs_apply('feeling_called_love');
            pc.buffs_alter_time('feeling_called_love', -(60 - this.buffs_get_remaining_duration('feeling_called_love')));
            pc.feeling_called_love_last_time = now;

            this.buffs_remove('feeling_called_love');
            this.feeling_called_love_last_time = now;
        }
    }
}

public function buffs_hairball_start() {
    this.hairball_dash = {
        distance: 0,
        street_start: this.player.x
    };
}

public function buffs_hairball_leave_street() {
    if (!this.hairball_dash) {
        log.error(this+" changing streets with hairball buff, but it has not been initialized correctly!");
        this.buffs_hairball_start();
        return;
    }
    this.hairball_dash.distance += Math.abs(this.hairball_dash.street_start - this.player.x);
}

public function buffs_hairball_enter_street() {
    if (!this.hairball_dash) {
        log.error(this+" changing streets with hairball buff, but it has not been initialized correctly!");
        this.buffs_hairball_start();
        return;
    }

    this.hairball_dash.street_start = this.player.x;
}

public function buffs_hairball_end() {
    if (this.hairball_dash) {
        this.hairball_dash.distance += Math.abs(this.hairball_dash.street_start - this.player.x);

        if (this.hairball_dash.distance > 14000) {
            this.player.achievements.achievements_set('essence_of_hairball', 'distance_dashed', this.hairball_dash.distance);
        }

        this.hairball_dash = null;
    }
}

public function buffs_enter_location(location) {
    if (this.buffs_has('hairball_dash')) {
        this.buffs_hairball_enter_street();
    }
}

public function buffs_charades_get_word() {
    return this.charades_word;
}

public function buffs_charades_guess_correct_word() {
    this['!charades_correct_guess'] = true;
    this.player.stats.charades = 'guessed';

    this.buffs_remove('charades');

    this.charades_word = null; // Just in case the debuff failed, this will stop message spamming.
}

public function buffs_charades_ruin() {
    this.player.stats.charades = 'ruined';
    this.buffs_remove('charades');
}

    }
}
