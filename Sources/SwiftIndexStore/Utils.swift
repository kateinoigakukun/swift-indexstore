enum IndexStoreResult<T, E: Error> {
    case success(T)
    case failure(E, T)
    
    init(result: Result<T, E>, whenError: T) {
        switch result {
        case .success(let t):
            self = .success(t)
        case .failure(let error):
            self = .failure(error, whenError)
        }
    }
}

extension IndexStoreResult where E == Error {
    init(
        whenError: @autoclosure () -> T,
        _ f: () throws -> T
    ) {
        do {
            self = try .success(f())
        } catch {
            self = .failure(error, whenError())
        }
    }
}


private class Context<T, R, E: Error> {
    var fn: (T) -> IndexStoreResult<R, E>
    var error: E?
    init(_ fn: @escaping (T) -> IndexStoreResult<R, E>) {
        self.fn = fn
    }
}

func wrapCapturingCFunction<T, FnR, ClosureR, E>(
    _ f: (UnsafeMutableRawPointer?, @escaping (UnsafeMutableRawPointer?, T) -> ClosureR) -> FnR,
    _ callback: (T) -> IndexStoreResult<ClosureR, E>
) -> Result<FnR, E> {
    typealias Ctx = Context<T, ClosureR, E>
    return withoutActuallyEscaping(callback) { callback in
        let handler = Ctx(callback)
        let ctx = Unmanaged.passUnretained(handler).toOpaque()
        let result = f(ctx) { ctx, value in
            let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
            switch ctx.fn(value) {
            case let .success(result): return result
            case let .failure(error, result):
                ctx.error = error
                return result
            }
        }
        if let error = handler.error {
            return .failure(error)
        } else {
            return .success(result)
        }
    }
}
