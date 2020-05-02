@propertyWrapper
public class Lazy<Value> {
    enum State {
        case uninitialized(() -> Value)
        case initialized(Value)
    }

    private var state: State

    public init(wrappedValue: @autoclosure @escaping () -> Value) {
        self.state = .uninitialized(wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            switch state {
            case .uninitialized(let initializer):
                let value = initializer()
                state = .initialized(value)
                return value
            case .initialized(let value):
                return value
            }
        }
        set {
            state = .initialized(newValue)
        }
    }
}
