package com.baturasys;

/** Activity metadata (result of activityMeta() in the PHP version). */
public class Activity {
    public String id;
    public String name;
    public String emoji;
    public String swatch;
    public String blurb;
    public double rate;
    public String unit;
    public double offsiteRate;
    public String offsiteUnit;

    Activity(String id, String name, String emoji, String swatch, String blurb,
             double rate, String unit, double offsiteRate, String offsiteUnit) {
        this.id = id;
        this.name = name;
        this.emoji = emoji;
        this.swatch = swatch;
        this.blurb = blurb;
        this.rate = rate;
        this.unit = unit;
        this.offsiteRate = offsiteRate;
        this.offsiteUnit = offsiteUnit;
    }

    Activity copy() {
        return new Activity(id, name, emoji, swatch, blurb, rate, unit, offsiteRate, offsiteUnit);
    }
}
