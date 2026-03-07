import { ICarrier } from '../../domain/ports/ICarrier';
import { UPSAdapter } from './ups/UPSAdapter';

export class CarrierFactory {
  private readonly carriers: Map<string, ICarrier>;

  constructor() {
    this.carriers = new Map();
    const upsAdapter = new UPSAdapter();
    this.carriers.set(upsAdapter.code, upsAdapter);
  }

  public getCarrier(code: string): ICarrier | undefined {
    return this.carriers.get(code);
  }
}
