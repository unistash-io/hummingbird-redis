//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import Logging
import NIOCore
import RediStack
import NIOSSL

import struct Foundation.URL

// Based of the Vapor redis configuration that can be found
// here https://github.com/vapor/redis/blob/master/Sources/Redis/RedisConfiguration.swift

public struct RedisConfiguration {
    public typealias ValidationError = RedisConnection.Configuration.ValidationError

    public var serverAddresses: [SocketAddress]
    public var username: String?
    public var password: String?
    public var database: Int?
    public var pool: PoolOptions
    public var tlsConfiguration: TLSConfiguration?

    public struct PoolOptions {
        public var maximumConnectionCount: RedisConnectionPoolSize
        public var minimumConnectionCount: Int
        public var connectionBackoffFactor: Float32
        public var initialConnectionBackoffDelay: TimeAmount
        public var connectionRetryTimeout: TimeAmount?

        public init(
            maximumConnectionCount: RedisConnectionPoolSize = .maximumActiveConnections(2),
            minimumConnectionCount: Int = 0,
            connectionBackoffFactor: Float32 = 2,
            initialConnectionBackoffDelay: TimeAmount = .milliseconds(100),
            connectionRetryTimeout: TimeAmount? = nil
        ) {
            self.maximumConnectionCount = maximumConnectionCount
            self.minimumConnectionCount = minimumConnectionCount
            self.connectionBackoffFactor = connectionBackoffFactor
            self.initialConnectionBackoffDelay = initialConnectionBackoffDelay
            self.connectionRetryTimeout = connectionRetryTimeout
        }
    }

    public init(url string: String, pool: PoolOptions = .init()) throws {
        guard let url = URL(string: string) else { throw ValidationError.invalidURLString }
        try self.init(url: url, pool: pool)
    }

    public init(url: URL, pool: PoolOptions = .init()) throws {
        guard
            let scheme = url.scheme,
            !scheme.isEmpty
        else { throw ValidationError.missingURLScheme }
        guard scheme == "redis" || scheme == "rediss" else { throw ValidationError.invalidURLScheme }
        guard let host = url.host, !host.isEmpty else { throw ValidationError.missingURLHost }

        try self.init(
            hostname: host,
            port: url.port ?? RedisConnection.Configuration.defaultPort,
            username: url.user,
            password: url.password,
            database: Int(url.lastPathComponent),
            pool: pool,
            tlsConfiguration: scheme == "rediss" ? .clientDefault : nil
        )
    }

    public init(
        hostname: String,
        port: Int = RedisConnection.Configuration.defaultPort,
        username: String? = nil,
        password: String? = nil,
        database: Int? = nil,
        pool: PoolOptions = .init(),
        tlsConfiguration: TLSConfiguration? = nil
    ) throws {
        if database != nil, database! < 0 { throw ValidationError.outOfBoundsDatabaseID }

        try self.init(
            serverAddresses: [.makeAddressResolvingHost(hostname, port: port)],
            username: username,
            password: password,
            database: database,
            pool: pool,
            tlsConfiguration: tlsConfiguration
        )
    }

    public init(
        serverAddresses: [SocketAddress],
        username: String? = nil,
        password: String? = nil,
        database: Int? = nil,
        pool: PoolOptions = .init(),
        tlsConfiguration: TLSConfiguration? = nil
    ) throws {
        self.serverAddresses = serverAddresses
        self.username = username
        self.password = password
        self.database = database
        self.pool = pool
        self.tlsConfiguration = tlsConfiguration
    }
}

extension RedisConnectionPool.Configuration {
    init(
        _ config: RedisConfiguration,
        logger: Logger
    ) {
        self.init(
            initialServerConnectionAddresses: config.serverAddresses,
            maximumConnectionCount: config.pool.maximumConnectionCount,
            connectionFactoryConfiguration: .init(
                connectionInitialDatabase: config.database,
                connectionUsername: config.username,
                connectionPassword: config.password,
                connectionDefaultLogger: logger,
                tcpClient: nil
            ),
            minimumConnectionCount: config.pool.minimumConnectionCount,
            connectionBackoffFactor: config.pool.connectionBackoffFactor,
            initialConnectionBackoffDelay: config.pool.initialConnectionBackoffDelay,
            connectionRetryTimeout: config.pool.connectionRetryTimeout,
            clientTLSConfiguration: config.tlsConfiguration,
            poolDefaultLogger: logger
        )
    }
}
