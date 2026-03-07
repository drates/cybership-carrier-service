import { RateRequest, RateQuote, RateId, Money } from '../../../domain/types';
import { UPSRateResponse } from './UPSSchemas';

export class UPSMapper {
  public static toUpsRateRequest(request: RateRequest): object {
    return {
      RateRequest: {
        Request: {
          TransactionReference: {
            CustomerContext: 'Cybership Rate Request',
          },
        },
        Shipment: {
          Shipper: {
            Name: 'Cybership',
            Address: {
              AddressLine: [request.origin.street1],
              City: request.origin.city,
              StateProvinceCode: request.origin.state,
              PostalCode: request.origin.postalCode,
              CountryCode: request.origin.country,
            },
          },
          ShipTo: {
            Name: 'Recipient',
            Address: {
              AddressLine: [request.destination.street1],
              City: request.destination.city,
              StateProvinceCode: request.destination.state,
              PostalCode: request.destination.postalCode,
              CountryCode: request.destination.country,
            },
          },
          ShipFrom: {
            Name: 'Shipper',
            Address: {
              AddressLine: [request.origin.street1],
              City: request.origin.city,
              StateProvinceCode: request.origin.state,
              PostalCode: request.origin.postalCode,
              CountryCode: request.origin.country,
            },
          },
          Service: {
          },
          Package: request.packages.map((pkg) => ({
            PackagingType: {
              Code: '02', 
              Description: 'Package',
            },
            Dimensions: {
              UnitOfMeasurement: { Code: 'CM' }, 
              Length: String(pkg.length),
              Width: String(pkg.width),
              Height: String(pkg.height),
            },
            PackageWeight: {
              UnitOfMeasurement: { Code: 'KGS' }, 
              Weight: String(pkg.weight),
            },
          })),
        },
      },
    };
  }

  public static toDomainRateQuotes(response: UPSRateResponse): RateQuote[] {
    const ratedShipments = response.RateResponse.RatedShipment;

    return ratedShipments.map((shipment): RateQuote => {
      const totalCost: Money = {
        amount: Math.round(parseFloat(shipment.TotalCharges.MonetaryValue) * 100),
        currency: shipment.TotalCharges.CurrencyCode,
      };

      const estimatedDelivery = shipment.GuaranteedDelivery?.BusinessDaysInTransit
        ? new Date(Date.now() + parseInt(shipment.GuaranteedDelivery.BusinessDaysInTransit) * 24 * 60 * 60 * 1000)
        : null;

      return {
        id: `ups-${shipment.Service.Code}-${crypto.randomUUID()}` as RateId,
        carrier: 'ups',
        serviceLevel: {
          name: shipment.Service.Description,
          token: shipment.Service.Code,
        },
        totalCost,
        estimatedDelivery,
      };
    });
  }
}
