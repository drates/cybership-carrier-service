export const upsAuthSuccessPayload = {
  token_type: 'Bearer',
  issued_at: '1678886400000',
  client_id: 'your_ups_client_id',
  access_token: 'stubbed_access_token_string',
  scope: 'oob',
  expires_in: '3599', 
  refresh_count: '0',
  status: 'approved',
};

export const upsRefreshedAuthSuccessPayload = {
    ...upsAuthSuccessPayload,
    access_token: 'refreshed_access_token_string',
};

export const upsRateSuccessPayload = {
  RateResponse: {
    RatedShipment: [
      {
        Service: { Code: '03', Description: 'UPS Ground' },
        TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '25.50' },
        GuaranteedDelivery: { BusinessDaysInTransit: '3' },
        RatedPackage: { TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '25.50' } },
      },
      {
        Service: { Code: '01', Description: 'UPS Next Day Air' },
        TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '78.15' },
        GuaranteedDelivery: { BusinessDaysInTransit: '1', DeliveryByTime: '10:30 AM' },
        RatedPackage: { TotalCharges: { CurrencyCode: 'USD', MonetaryValue: '78.15' } },
      },
    ],
  },
};

export const upsApiErrorPayload = {
  response: {
    errors: [
      {
        code: '250003',
        message: 'Invalid or missing shipper number.',
      },
    ],
  },
};
