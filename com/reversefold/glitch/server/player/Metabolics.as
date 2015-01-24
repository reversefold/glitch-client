package com.reversefold.glitch.server.player {
    import com.reversefold.glitch.server.Common;
    import com.reversefold.glitch.server.Prop;
    import com.reversefold.glitch.server.data.Config;
    import com.reversefold.glitch.server.player.Player;
    
    import org.osmf.logging.Log;
    import org.osmf.logging.Logger;

    public class Metabolics {
        private static var log : Logger = Log.getLogger("server.Player");

        public var config : Config;
        public var player : Player;

		public var energy : Prop;
		public var mood : Prop;
		public var tank : int;
		public var dontGetPooped : Boolean;
		
        public function Metabolics(config : Config, player : Player) {
            this.config = config;
            this.player = player;
        }


public function metabolics_init(){
    var max = this.metabolics_calc_max(this.player.stats.level);
    this.energy = new Prop(max, 0, max);
    this.mood = new Prop(max, 0, max);

    // This seems unnecessary
    //this.metabolics_recalc_limits(false);

    if (!this.tank) this.tank = this.energy.top;
}



public function metabolics_get_login(out){

    out.energy = {
        value   : this.energy.value,
        max : this.energy.top
    };

    out.mood = {
        value   : this.mood.value,
        max : this.mood.top
    };
}

/* Prevent a player who is low on energy from becoming pooped until
 * they next go above five energy. Used by Wine of the Dead.
 */
public function metabolics_dont_get_pooped() {
    this.dontGetPooped  = true;
}

public function metabolics_add_energy(x, quiet=false, force=false){

    if (this.player.is_dead){
        if (!quiet){
            this.player.sendOnlineActivity("You would have gained energy, but you're dead!");
        }
        return 0;
    }
    else if (this.player.buffs.buffs_has('super_pooped')){
        if (!quiet){
            this.player.sendOnlineActivity("You would have gained energy, but you're super pooped!");
        }
        return 0;
    }

    var change = this.energy.apiInc(x);

    this.player.daily_history.daily_history_increment('energy_gained', change);

    if (change && !quiet){
        this.player.announcements.apiSendAnnouncement({
            type: "energy_stat",
            delta: change
        });
    }

    if (this.metabolics_get_percentage('energy') > 5) {
        if (this.player.buffs.buffs_has('pooped')){
            this.player.buffs.buffs_remove('pooped');
        }

        if (this.dontGetPooped ) {
            this.dontGetPooped = false;
        }
    }

    return change;
}

public function metabolics_add_mood(x, quiet=false, force=false){

    if (this.player.is_dead){
        if (!quiet){
            this.player.sendOnlineActivity("You would have gained some mood, but you're dead!");
        }
        return 0;
    }

    var change = this.mood.apiInc(x);

    if (change && !quiet){
        this.player.announcements.apiSendAnnouncement({
            type: "mood_stat",
            delta: change
        });
    }

    return change;
}

public function metabolics_try_lose_energy(x){
    if (this.metabolics_get_energy() > x){
        return this.metabolics_lose_energy(x);
    }

    return 0;
}

public function metabolics_lose_energy(x, quiet=false, force=false){

    // No energy loss during newxp
    if (!force){
        if (this.player.location.is_newxp && (this.player.location.isInstance('newxp_intro') || this.player.location.isInstance('newxp_training1'))){
            return 0;
        }
    }

    if (this.player.is_dead){
        if (!quiet){
            this.player.sendOnlineActivity("You would have lost energy, but you're dead!");
        }
        return 0;
    }

    var change = this.energy.apiDec(x);

    if (change && !quiet){
        this.player.announcements.apiSendAnnouncement({
            type: "energy_stat",
            delta: change
        });
    }


    this.player.daily_history.daily_history_increment('energy_consumed', change * -1);

    // Check for croaking
    if (this.metabolics_get_energy() == 0 && !this.player.deaths_today && !this.player.buffs.buffs_has('no_no_powder')){
        // 1. If you get down below the DEATH THRESHOLD (I think that's less than 2% of energy?) on a given day, you die. That will be the only time you die that day.
        log.info(this+' croaking due to low energy');
        this.player.croak();
    }
    // Check for pooped
    else if (this.metabolics_get_percentage('energy') <= 5 && !this.player.is_dead && this.player.deaths_today && !this.dontGetPooped ){
        var tomorrow = Common.timestamp_to_gametime(Common.time()+ (Common.game_days_to_ms(1)/1000));
        tomorrow[3] = 0;
        tomorrow[4] = 0;

        var remaining = Common.gametime_to_timestamp(tomorrow) - Common.time();
        if (this.player.daily_history.daily_history_get(Common.current_day_key(), 'energy_consumed') >= this.energy.top * 20 && !this.player.buffs.buffs_has('super_pooped')){
            if (this.player.buffs.buffs_has('pooped')) this.player.buffs.buffs_remove('pooped');
            this.player.buffs.buffs_apply('super_pooped', {duration: remaining});
        }
        else if (!this.player.buffs.buffs_has('pooped') && !this.player.buffs.buffs_has('super_pooped')){
            this.player.buffs.buffs_apply('pooped', {duration: remaining});
        }
    };

    if (this.metabolics_get_percentage('energy') <= 10 && !this.player.buffs.buffs_has('walking_dead') && !this.player.is_dead && Common.time() - this['!last_energy_warning'] > 60){
        if (this.player.deaths_today){
            this.player.sendOnlineActivity('You are extremely low on energy! Find something to eat.');
        }
        else{
            this.player.sendOnlineActivity('You are about to croak! Find something to eat.');
        }

        this['!last_energy_warning'] = Common.time();
    }

    return change;
}

public function metabolics_try_lose_mood(x){
    if (this.metabolics_get_mood() > x){
        return this.metabolics_lose_mood(x);
    }

    return 0;
}

public function metabolics_lose_mood(x, quiet=false, force=false){

    // No mood loss during newxp
    if (!force){
        if (this.player.location.is_newxp && (this.player.location.isInstance('newxp_intro') || this.player.location.isInstance('newxp_training1'))){
            return 0;
        }
    }

    if (this.player.is_dead){
        if (!quiet){
            this.player.sendOnlineActivity("You would have lost some mood, but you're dead!");
        }
        return 0;
    }

    var change = this.mood.apiDec(x);

    if (change && !quiet){
        this.player.announcements.apiSendAnnouncement({
            type: "mood_stat",
            delta: change
        });
    }

    if (this.player.location.instance_id != 'tower_quest_desert'){
        if (this.metabolics_get_percentage('mood') <= 20 && !this.player.buffs.buffs_has('walking_dead') && !this.player.is_dead){
            this.player.sendOnlineActivity('Your mood is getting very low! Try drinking something tasty.');
        }
        else if (this.metabolics_get_percentage('mood') <= 50 && !this.player.buffs.buffs_has('walking_dead') && !this.player.is_dead){
            //this.player.sendOnlineActivity('Your mood is getting low. Watch it: you\'ll start burning energy faster.');
            this.player.sendOnlineActivity('Your mood is getting low. Drink something, else you\'ll earn less iMG for your actions.');
        }
    }

    if (this.metabolics_get_mood() == 0 && this.player.is_god){
        this.player.quests.quests_offer('zero_mood');
    }

    return change;
}

public function metabolics_get_energy(){
    return this.energy.value;
}

public function metabolics_get_mood(){
    return this.mood.value;
}

public function metabolics_set_energy(x, quiet = false, force = false){

    if (this.energy.top < x){
        x = this.energy.top;
    }

    var change = x - this.metabolics_get_energy();

    if (change > 0){
        return this.metabolics_add_energy(change, quiet, force);
    }
    else if (change < 0){
        return this.metabolics_lose_energy(Math.abs(change), quiet, force);
    }
    else{
        return 0;
    }
}

public function metabolics_set_mood(x, quiet = false, force = false){
    if (this.mood.top < x){
        x = this.mood.top;
    }

    var change = x - this.metabolics_get_mood();
    if (change > 0){
        return this.metabolics_add_mood(change, quiet, force);
    }
    else if (change < 0){
        return this.metabolics_lose_mood(Math.abs(change), quiet, force);
    }
    else{
        return 0;
    }
}

public function metabolics_recalc_limits(set_to_max){

    //log.info(this+' metabolics_recalc_limits 1: '+set_to_max);
    if (set_to_max === undefined){
        set_to_max = true;
    }
    //log.info(this+' metabolics_recalc_limits 2: '+set_to_max);

    var max = this.metabolics_calc_max(this.player.stats.level);
    this.metabolics_set_max('energy', max);
    this.metabolics_set_max('mood', max);

    if (set_to_max){
        this.energy.apiSet(max);
        this.mood.apiSet(max);

        if (this.player.buffs.buffs_has('pooped')){
            this.player.buffs.buffs_remove('pooped');
        }

        if (this.dontGetPooped ) {
            this.dontGetPooped = false;
        }
    }

    //log.info('metabolic limit at level '+this.player.stats.level+' is '+max);
}

// This will currently be reset any time metabolics_recalc_limits is called
public function metabolics_set_max(metabolic, max){
    if (!this[metabolic]) return false;

    if (this[metabolic].top != max){
        this[metabolic].apiSetLimits(0, max);
    }

    if (this[metabolic].value > max){
        this[metabolic].apiSet(max);
    }

    return true;
}

public function metabolics_get_percentage(stat){
    return this[stat].value / this[stat].top * 100;
}

public function metabolics_calc_max(level, ignore_buffs=false){

    // Some buffs artificially restrict your max amounts
    if (!ignore_buffs){
        if (this.player.buffs.buffs_has('real_bummer')){
            return 30;
        }
        else if (this.player.buffs.buffs_has('bad_mood')){
            return 60;
        }
        else if (this.player.buffs.buffs_has('rooked_recovery')){
            var actual_max = this.metabolics_calc_max(level, true);
            return actual_max / 2;
        }
    }

    // If iMG is on, then our max is our max!
    if (this.metabolics_get_tank()){
        return this.metabolics_get_tank();
    }

    var max = 100;
    var counter = 0;
    var target = 5;
    var step = 10;

    for (var i=1; i<level; i++){

        max += step;

        counter++;
        if (counter == target){
            counter = 0;
            target++;
            step += 10;
        }
    }

    return max;
}

public function metabolics_test(){

    for (var i=1; i<30; i++){

        var n = this.metabolics_calc_max(i);

        log.info('max energy',i,n);
    }

}


public function metabolics_try_set(stat, val){
    if (this[stat].top < val){
        val = this[stat].top;
    }
    return val;
}

public function metabolics_try_inc(stat, val){
    if (this.player.is_dead) return 0;
    if (this.player.buffs.buffs_has('super_pooped')) return 0;
    var remain = this[stat].top - this[stat].value;
    return val > remain ? remain : val;
}

public function metabolics_try_dec(stat, val){
    if (this.player.is_dead) return 0;
    var cur = this[stat].value;
    return val > cur ? cur : val;
}

public function metabolics_get_max_energy(){
    this.metabolics_init();
    return this.energy.top;
}

public function metabolics_get_max_mood(){
    this.metabolics_init();
    return this.mood.top;
}

public function metabolics_get_tank(){
    return this.tank;
}

public function metabolics_set_tank(tank){
    this.tank = tank;
}

    }
}
