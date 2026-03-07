export type RateId = string & { readonly __brand: 'RateId' };
export type ShipmentId = string & { readonly __brand: 'ShipmentId' };

export interface Address {
  street1: string;
  street2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string; 
}

export interface Package {
  weight: number; 
  length: number; 
  width: number; 
  height: number; 
}

export interface Money {
  amount: number; 
  currency: string; 
}

export interface RateRequest {
  origin: Address;
  destination: Address;
  packages: Package[];
}

export interface RateQuote {
  id: RateId;
  carrier: string; 
  serviceLevel: {
    name: string; 
    token: string; 
  };
  totalCost: Money;
  estimatedDelivery: Date | null;
}
