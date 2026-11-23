package com.baturasys;

import java.io.Serializable;

/** One line in the booking cart ($_SESSION['booking_cart'][] in PHP). */
public class CartItem implements Serializable {
    private static final long serialVersionUID = 1L;

    public String activityId;
    public String activityName;
    public String emoji;
    public String swatch;
    public String slot;
    public int hours;
    public int count;
    public double rate;
    public String unit;
    public String date;
    public String rentalType;
}
