//
//  DuckDB
//  https://github.com/duckdb/duckdb-swift
//
//  Copyright © 2018-2023 Stichting DuckDB Foundation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

@_implementationOnly import Cduckdb
import Foundation

/// DuckDB index type
public typealias DBInt = UInt64

/// An object representing a DuckDB database
///
/// A Database can be initialized using a local file store, or alternatively,
/// using an in-memory store. Note that for an in-memory database no data is
/// persisted to disk (i.e. all data is lost when you exit the process).
public final class Database {
  
  /// Duck DB database store type
  public enum Store {
    /// A local file based database store
    case file(at: URL)
    /// An in-memory database store
    case inMemory
  }
  
  private let ptr = UnsafeMutablePointer<duckdb_database?>.allocate(capacity: 1)
  
  /// Creates a Duck DB database
  ///
  /// A DuckDB database can be initilaized using either a local database file or
  /// using an in-memory store
  ///
  /// - Note: An in-memory database does not persist data to disk. All data is
  ///   lost when you exit the process.
  /// - Parameter store: the store to initialize the database with
  /// - Throws: ``DatabaseError/databaseFailedToInitialize(reason:)`` if the
  ///   database failed to instantiate
  public convenience init(store: Store = .inMemory) throws {
    var fileURL: URL?
    if case .file(let url) = store {
      guard url.isFileURL else {
        throw DatabaseError.databaseFailedToInitialize(
          reason: "provided URL for database store file must be local")
      }
      fileURL = url
    }
    try self.init(path: fileURL?.path, config: nil)
  }
  
  private init(path: String?, config: duckdb_config?) throws {
    let outError = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: 1)
    defer { outError.deallocate() }
    let status = path.withOptionalCString { strPtr in
      duckdb_open_ext(strPtr, ptr, config, outError)
    }
    guard status == .success else {
      let error = outError.pointee.map { ptr in
        defer { duckdb_free(ptr) }
        return String(cString: ptr)
      }
      throw DatabaseError.databaseFailedToInitialize(reason: error)
    }
  }
  
  deinit {
    duckdb_close(ptr)
    ptr.deallocate()
  }
  
  /// Creates a connection to the database
  ///
  /// See ``Connection/init(database:)`` for further discussion
  ///
  /// - Throws: ``DatabaseError/connectionFailedToInitialize`` if the connection
  /// could not be instantiated
  /// - Returns: a database connection
  public func connect() throws -> Connection {
    try .init(database: self)
  }
  
  func withCDatabase<T>(_ body: (duckdb_database?) throws -> T) rethrows -> T {
    try body(ptr.pointee)
  }
}
