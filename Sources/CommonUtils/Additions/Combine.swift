//
//  File.swift
//  
//
//  Created by Ilya Kuznetsov on 28/12/2022.
//

import Combine
import Foundation
import SwiftUI

public typealias ValuePublisher<T> = PassthroughSubject<T, Never>

public typealias VoidPublisher = PassthroughSubject<Void, Never>

@propertyWrapper
public class NonPublish<T>: ObservableObject {
    
    private var value: T
    
    public init(wrappedValue value: @escaping @autoclosure ()->T) {
        self.value = value()
    }

    public var wrappedValue: T {
        get { value }
        set { value = newValue }
    }
}

@propertyWrapper
public class PublishedDidSet<Value> {
    private var val: Value
    private let subject: CurrentValueSubject<Value, Never>

    public init(wrappedValue value: Value) {
        val = value
        subject = CurrentValueSubject(value)
        wrappedValue = value
    }

    public var wrappedValue: Value {
        set {
            val = newValue
            subject.send(val)
        }
        get { val }
    }
    
    public var projectedValue: CurrentValueSubject<Value, Never> {
        get { subject }
    }
}

public extension Publisher where Failure == Never {
    
    @discardableResult
    func sinkOnMain(retained: AnyObject? = nil, _ closure: @MainActor @escaping (Output)->()) -> AnyCancellable {
        let result = receive(on: DispatchQueue.main).sink(receiveValue: { value in
            Task { @MainActor in
                closure(value)
            }
        })
        if let retained = retained {
            result.retained(by: retained)
        }
        return result
    }
}

public extension Published.Publisher {
    
    @discardableResult
    mutating func sinkOnMain(retained: AnyObject? = nil, dropFirst: Bool = true, _ closure: @MainActor @escaping (Value)->()) -> AnyCancellable {
        let result = self.dropFirst(dropFirst ? 1 : 0).receive(on: DispatchQueue.main).sink(receiveValue: { value in
            Task { @MainActor in
                closure(value)
            }
        })
        if let retained = retained {
            result.retained(by: retained)
        }
        return result
    }
}

public extension ObservableObject {
    
    @discardableResult
    func sinkOnMain(retained: AnyObject? = nil, _ closure: @MainActor @escaping ()->()) -> AnyCancellable {
        let result =  objectWillChange.receive(on: DispatchQueue.main).sink { _ in
            Task { @MainActor in
                closure()
            }
        }
        
        if let retained = retained {
            result.retained(by: retained)
        }
        return result
    }
    
    @discardableResult
    func sink(retained: AnyObject? = nil, _ closure: @escaping ()->()) -> AnyCancellable {
        let result =  objectWillChange.sink { _ in closure() }
        
        if let retained = retained {
            result.retained(by: retained)
        }
        return result
    }
}

@propertyWrapper
public struct BindingPublished<Value>: DynamicProperty {
    
    @Binding private var binding: Value
    @State private var value: Value
    
    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            value = newValue
            binding = newValue
        }
    }
    
    public init(_ binding: Binding<Value>) {
        _binding = binding
        _value = State(initialValue: binding.wrappedValue)
    }
    
    public var projectedValue: Binding<Value> { $value }
}

@MainActor
@propertyWrapper
public final class RePublished<Value: ObservableObject> {
    
    public static subscript<T: ObservableObject>(
        _enclosingInstance instance: T,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<T, RePublished>) -> Value {
        get {
            if instance[keyPath: storageKeyPath].observer == nil {
                instance[keyPath: storageKeyPath].setupObserver(instance)
            }
            return instance[keyPath: storageKeyPath].value
        }
        set {
            instance[keyPath: storageKeyPath].value = newValue
            instance[keyPath: storageKeyPath].setupObserver(instance)
        }
    }
    
    private func setupObserver<T: ObservableObject>(_ instance: T) {
        observer = value.objectWillChange.sink { [unowned instance] _ in
            (instance.objectWillChange as any Publisher as? ObservableObjectPublisher)?.send()
        }
    }

    private var observer: AnyCancellable?
    
    @available(*, unavailable,
        message: "This property wrapper can only be applied to classes"
    )
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }
    
    private var value: Value
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    //public var projectedValue: AnyPublisher<Value, Never> {
    //    wrappedValue.objectWillChange
    //}
}

public extension Publisher {
    
    func map<T>(_ transform: @escaping (Output) async throws -> T) -> Publishers.FlatMap<Future<T, Error>, Publishers.SetFailureType<Self, Error>> {
        flatMap { value in
            Future { promise in
                Task {
                    do {
                        let output = try await transform(value)
                        promise(.success(output))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
    }
    
    func map<T>(_ transform: @escaping (Output) async -> T) -> Publishers.FlatMap<Future<T, Never>, Self> {
        flatMap { value in
            Future { promise in
                Task {
                    promise(.success(await transform(value)))
                }
            }
        }
    }
}
