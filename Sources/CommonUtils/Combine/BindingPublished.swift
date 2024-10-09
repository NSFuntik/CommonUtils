//
//  BindingPublished.swift
//  
//
//  Created by Ilya Kuznetsov on 22/08/2023.
//
import Foundation
import SwiftUI
/// A property wrapper that allows for a `Binding` to be published and observed.
/// This wrapper serves as a bridge between `@Binding` and `@Published`.
@propertyWrapper
public struct BindingPublished<Value>: DynamicProperty {
    
    /// A class that holds the state of the binding, conforming to `ObservableObject`.
    /// It manages the underlying binding and provides a published value.
    public final class State: ObservableObject {
        let binding: Binding<Value>
        
        /// A published value that automatically updates the binding when changed.
        @Published public var value: Value {
            didSet { binding.wrappedValue = value }
        }
        
        /// Initializes the state with the given binding.
        /// - Parameter binding: The binding to be managed.
        init(binding: Binding<Value>) {
            self.binding = binding
            self.value = binding.wrappedValue
        }
    }
    
    @StateObject public var state: State
    
    /// The current value of the wrapped property.
    public var wrappedValue: Value {
        get { state.value }
        nonmutating set { state.value = newValue }
    }
    
    /// Creates a `BindingPublished` with the specified binding.
    /// - Parameter binding: The binding to be wrapped.
    public init(_ binding: Binding<Value>) {
        _state = .init(wrappedValue: .init(binding: binding))
    }
    
    /// A `Binding` of the wrapped value, allowing for two-way data binding.
    public var projectedValue: Binding<Value> { .init(get: { wrappedValue }, set: { wrappedValue = $0 }) }
}
