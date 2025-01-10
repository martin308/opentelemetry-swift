/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class StdoutMetricExporter: StableMetricExporter {
    let isDebug: Bool
    var aggregationTemporalitySelector: AggregationTemporalitySelector
    
    public init(isDebug: Bool, aggregationTemporalitySelector: AggregationTemporalitySelector = AggregationTemporality.alwaysCumulative()) {
        self.isDebug = isDebug
        self.aggregationTemporalitySelector = aggregationTemporalitySelector
    }
    
    public func export(metrics: [OpenTelemetrySdk.StableMetricData]) -> OpenTelemetrySdk.ExportResult {
        if isDebug {
            for metric in metrics {
                print(String(repeating: "-", count: 40))
                print("Name: \(String(describing: metric.name))")
                print("Description: \(String(describing: metric.description))")
                print("Unit: \(String(describing: metric.unit))")
                print("IsMonotonic: \(String(describing: metric.isMonotonic))")
                print("\(metric.resource)")
                print("\(metric.instrumentationScopeInfo)")
                print("Type: \(metric.type)")
                print("AggregationTemporality: \(metric.data.aggregationTemporality)")
                if !metric.data.points.isEmpty {
                    print("DataPoints:")
                    for point in metric.data.points {
                        print("  - StartEpochNanos: \(point.startEpochNanos)")
                        print("    EndEpochNanos: \(point.endEpochNanos)")
                        print("    Attributes: \(point.attributes)")
                        print("    Exemplars:")
                        for exemplar in point.exemplars {
                            print("      - EpochNanos: \(exemplar.epochNanos)")
                            if let ctx = exemplar.spanContext {
                                print("        SpanContext: \(ctx)")
                            }
                            print("        FilteredAttributes: \(exemplar.filteredAttributes)")
                            if let e = exemplar as? DoubleExemplarData {
                                print("        Value: \(e.value)")
                            }
                            if let e = exemplar as? LongExemplarData {
                                print("        Value: \(e.value)")
                            }
                        }
                    }
                }
                print(String(repeating: "-", count: 40) + "\n")
            }
        }  else {
            let jsonEncoder = JSONEncoder()
            for metric in metrics {
                do {
                    let jsonData = try jsonEncoder.encode(MetricExporterData(metric: metric))
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } catch {
                    print("Failed to serialize Metric as JSON: \(error)")
                    return .failure
                }
            }
        }
        
        return .success
    }
    
    public func flush() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    public func shutdown() -> OpenTelemetrySdk.ExportResult {
        return .success
    }
    
    public func getAggregationTemporality(for instrument: OpenTelemetrySdk.InstrumentType) -> OpenTelemetrySdk.AggregationTemporality {
        return aggregationTemporalitySelector.getAggregationTemporality(for: instrument)
    }
}

private struct MetricExporterData {
    private let name: String
    private let description: String
    private let unit: String
    private let isMonotonic: Bool
    private let resource: Resource
    private let instrumentationScopeInfo: InstrumentationScopeInfo
    private let type: MetricDataType
    private let data: StableMetricData.Data
    
    init(metric: StableMetricData) {
        self.name = metric.name
        self.description = metric.description
        self.unit = metric.unit
        self.isMonotonic = metric.isMonotonic
        self.resource = metric.resource
        self.instrumentationScopeInfo = metric.instrumentationScopeInfo
        self.type = metric.type
        self.data = metric.data
    }
}

extension MetricExporterData: Encodable {
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case unit
        case isMonotonic
        case resource
        case instrumentationScopeInfo
        case type
        case data
    }
    
    struct AttributesCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
    }
    
    enum AttributeValueCodingKeys: String, CodingKey {
        case description
    }
    
    enum DataValueCodingKeys: String, CodingKey {
        case aggregationTemporality
        case points
    }
    
    enum DataPointCodingKeys: String, CodingKey {
        case startEpochNanos
        case endEpochNanos
        case attributes
        case exemplars
    }
    
    enum ExemplarCodingKeys: String, CodingKey {
        case epochNanos
        case filteredAttributes
        case value
        case spanContext
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(unit, forKey: .unit)
        try container.encode(isMonotonic, forKey: .isMonotonic)
        var resourceContainer = container.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .resource)
        
        try resource.attributes.forEach { attribute in
            if let attributeValueCodingKey = AttributesCodingKeys(stringValue: attribute.key) {
                var attributeValueContainer = resourceContainer.nestedContainer(keyedBy: AttributeValueCodingKeys.self, forKey: attributeValueCodingKey)
                
                try attributeValueContainer.encode(attribute.value.description, forKey: .description)
            }
        }
        
        try container.encode(instrumentationScopeInfo, forKey: .instrumentationScopeInfo)
        try container.encode("\(type)", forKey: .type)
        
        var dataContainer = container.nestedContainer(keyedBy: DataValueCodingKeys.self, forKey: .data)
        
        try dataContainer.encode("\(data.aggregationTemporality)", forKey: DataValueCodingKeys.aggregationTemporality)
        
        var dataPointContainer = dataContainer.nestedUnkeyedContainer(forKey: .points)
        
        try data.points.forEach { point in
            var pointContainer = dataPointContainer.nestedContainer(keyedBy: DataPointCodingKeys.self)
            
            try pointContainer.encode(point.startEpochNanos, forKey: .startEpochNanos)
            try pointContainer.encode(point.endEpochNanos, forKey: .endEpochNanos)
            
            var attributeContainer = pointContainer.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .attributes)
            
            try point.attributes.forEach { attribute in
                if let attributeValueCodingKey = AttributesCodingKeys(stringValue: attribute.key) {
                    var attributeValueContainer = attributeContainer.nestedContainer(keyedBy: AttributeValueCodingKeys.self, forKey: attributeValueCodingKey)
                    
                    try attributeValueContainer.encode(attribute.value.description, forKey: .description)
                }
            }
            
            var exemplarsContainer = pointContainer.nestedUnkeyedContainer(forKey: .exemplars)
            
            try point.exemplars.forEach { exemplar in
                var exemplarContainer = exemplarsContainer.nestedContainer(keyedBy: ExemplarCodingKeys.self)
                
                try exemplarContainer.encode(exemplar.epochNanos, forKey: .epochNanos)
                
                if let e = exemplar as? DoubleExemplarData {
                    try exemplarContainer.encode(e.value, forKey: .value)
                }
                if let e = exemplar as? LongExemplarData {
                    try exemplarContainer.encode(e.value, forKey: .value)
                }
                
                if let ctx = exemplar.spanContext {
                    try exemplarContainer.encode(ctx, forKey: .spanContext)
                }
                
                var filteredAttributes = exemplarContainer.nestedContainer(keyedBy: AttributesCodingKeys.self, forKey: .filteredAttributes)
                
                try exemplar.filteredAttributes.forEach { attribute in
                    if let attributeValueCodingKey = AttributesCodingKeys(stringValue: attribute.key) {
                        var attributeValueContainer = filteredAttributes.nestedContainer(keyedBy: AttributeValueCodingKeys.self, forKey: attributeValueCodingKey)
                        
                        try attributeValueContainer.encode(attribute.value.description, forKey: .description)
                    }
                }
            }
        }
    }
}
