import { z } from 'zod';

export const upsRateResponseSchema = z.object({
  RateResponse: z.object({
    RatedShipment: z.array(
      z.object({
        Service: z.object({
          Code: z.string(),
          Description: z.string(),
        }),
        RatedShipmentWarning: z.string().optional(),
        TotalCharges: z.object({
          CurrencyCode: z.string(),
          MonetaryValue: z.string(),
        }),
        GuaranteedDelivery: z
          .object({
            BusinessDaysInTransit: z.string(),
            DeliveryByTime: z.string().optional(),
          })
          .optional(),
        RatedPackage: z.object({
          TotalCharges: z.object({
            CurrencyCode: z.string(),
            MonetaryValue: z.string(),
          }),
        }),
      })
    ),
  }),
});

export type UPSRateResponse = z.infer<typeof upsRateResponseSchema>;
