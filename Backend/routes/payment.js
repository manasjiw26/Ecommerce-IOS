const express = require('express');
const router = express.Router();
const Razorpay = require('razorpay');
const crypto = require('crypto');
require('dotenv').config();

const razorpayInstance = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET
});

// Create Order endpoint
router.post('/create-order', async (req, res) => {
    try {
        const { amount } = req.body; // Amount should be passed in normal currency value (e.g. 50.00)
        
        const options = {
            amount: Math.round(amount * 100), // amount in smallest currency unit (cents/paise)
            currency: "INR",
            receipt: `receipt_${Date.now()}`
        };

        const order = await razorpayInstance.orders.create(options);

        if (!order) {
            return res.status(500).json({ error: "Failed to create order with Razorpay" });
        }

        res.json(order);
    } catch (error) {
        console.error("Razorpay error:", error);
        res.status(500).json({ error: error.message });
    }
});

// Verify Payment endpoint
router.post('/verify', async (req, res) => {
    try {
        const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

        const body = razorpay_order_id + "|" + razorpay_payment_id;

        const expectedSignature = crypto
            .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
            .update(body.toString())
            .digest("hex");

        const isAuthentic = expectedSignature === razorpay_signature;

        if (isAuthentic) {
            // Payment successful
            // TODO: Update your Supabase database with the order status here
            res.json({ message: "Payment Verified Successfully", payment_id: razorpay_payment_id });
        } else {
            res.status(400).json({ error: "Invalid Signature" });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
