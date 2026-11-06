require('dotenv').config();

const crypto = require('node:crypto');
const express = require('express');
const midtransClient = require('midtrans-client');

const app = express();
const port = Number(process.env.PORT || 3000);
const serverKey = process.env.MIDTRANS_SERVER_KEY;
const snap = serverKey
  ? new midtransClient.Snap({ isProduction: false, serverKey })
  : null;

app.use(express.json({ limit: '16kb' }));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    environment: 'sandbox',
    midtransConfigured: Boolean(snap),
  });
});

app.post('/api/payments/snap', async (request, response) => {
  if (!snap) {
    return response.status(503).json({
      message: 'MIDTRANS_SERVER_KEY belum diatur pada backend.',
    });
  }

  const amount = Number(request.body.amount);
  const itemName = String(request.body.itemName || 'Booking lapangan').trim();
  const customerName = String(request.body.customerName || 'Pelanggan').trim();
  const customerEmail = String(request.body.customerEmail || '').trim();

  if (!Number.isSafeInteger(amount) || amount <= 0) {
    return response.status(400).json({ message: 'Nominal pembayaran tidak valid.' });
  }
  if (!customerEmail || !/^\S+@\S+\.\S+$/.test(customerEmail)) {
    return response.status(400).json({ message: 'Email pelanggan tidak valid.' });
  }

  const orderId = `sf-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

  try {
    const transaction = await snap.createTransaction({
      transaction_details: {
        order_id: orderId,
        gross_amount: amount,
      },
      item_details: [
        {
          id: 'sportsfield-booking',
          price: amount,
          quantity: 1,
          name: itemName.slice(0, 50),
        },
      ],
      customer_details: {
        first_name: customerName.slice(0, 50),
        email: customerEmail,
      },
    });

    response.status(201).json({
      orderId,
      token: transaction.token,
      redirectUrl: transaction.redirect_url,
    });
  } catch (error) {
    console.error('Midtrans Snap transaction creation failed:', error.message);
    response.status(502).json({
      message: 'Midtrans Sandbox gagal membuat transaksi.',
    });
  }
});

app.get('/api/payments/:orderId/status', async (request, response) => {
  if (!snap) {
    return response.status(503).json({
      message: 'MIDTRANS_SERVER_KEY belum diatur pada backend.',
    });
  }

  const { orderId } = request.params;
  if (!/^sf-\d+-[a-f0-9]{8}$/.test(orderId)) {
    return response.status(400).json({ message: 'Order ID tidak valid.' });
  }

  try {
    const transaction = await snap.transaction.status(orderId);
    const transactionStatus = transaction.transaction_status;
    const isPaid =
      transactionStatus === 'settlement' ||
      (transactionStatus === 'capture' && transaction.fraud_status === 'accept');

    response.json({
      orderId,
      transactionStatus,
      isPaid,
    });
  } catch (error) {
    console.error('Midtrans transaction status check failed:', error.message);
    response.status(502).json({
      message: 'Status pembayaran belum dapat diperiksa.',
    });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Midtrans Sandbox backend listening on http://0.0.0.0:${port}`);
});