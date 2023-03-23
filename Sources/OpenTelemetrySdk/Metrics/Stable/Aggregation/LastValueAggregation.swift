//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class LastValueAggregation : Aggregation, AggregatorFactory {
    public private(set) static var instance = LastValueAggregation()

    public func createAggregator(descriptor: InstrumentDescriptor, exemplarFilter: ExemplarFilter) -> StableAggregator {
        switch descriptor.valueType {
        case .double:
            return DoubleLastValueAggregator(resevoirSupplier: {
                FilteredExemplarReservoir(filter:exemplarFilter, reservoir: RandomFixedSizedExemplarReservoir.createDouble(clock: MillisClock(), size: 2))
            })
        case .long:
            return LongLastValueAggregator(resevoirSupplier: {
                FilteredExemplarReservoir(filter: exemplarFilter, reservoir: RandomFixedSizedExemplarReservoir.createLong(clock: MillisClock(), size: 2))
            })
        }
    }
    
    public func isCompatible(with descriptor: InstrumentDescriptor) -> Bool {
        return descriptor.type == .observableGauge
    }
    
}
