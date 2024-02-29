//
//  EIP712Meta.swift
//
//
//  Created by Petar Kopestinskij on 27.2.24..
//

import Foundation
import BigInt

public struct EIP712Meta: Codable {

    public var gasPerPubdata: BigUInt?

    public var customSignature: Data? = Data()

    public var paymasterParams: PaymasterParams?

    public var factoryDeps: [Data]?

    enum CodingKeys: String, CodingKey {
        case gasPerPubdata
        case customSignature
        case paymasterParams
        case factoryDeps
    }

    public init(gasPerPubdata: BigUInt? = nil,
                customSignature: Data? = Data(),
                paymasterParams: PaymasterParams? = nil,
                factoryDeps: [Data]? = nil) {
        self.gasPerPubdata = gasPerPubdata
        self.customSignature = customSignature
        self.paymasterParams = paymasterParams
        self.factoryDeps = factoryDeps
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let gasPerPubdata = gasPerPubdata {
            try container.encode(gasPerPubdata.data.toHexString().addHexPrefix(), forKey: .gasPerPubdata)
        }
        if let customSignature = customSignature {
            try container.encode(customSignature.toHexString().addHexPrefix(), forKey: .customSignature)
        }
        if let paymasterParams = paymasterParams {
            try container.encode(paymasterParams, forKey: .paymasterParams)
        }
        if let factoryDeps = self.factoryDeps {
            try container.encode(factoryDeps.compactMap({ $0.bytes }), forKey: .factoryDeps)
        }
    }
}

public struct PaymasterParams: Codable {

    public var paymaster: EthereumAddress?

    public var paymasterInput: Data?

    enum CodingKeys: String, CodingKey {
        case paymaster
        case paymasterInput
    }

    public init(paymaster: EthereumAddress? = nil,
                paymasterInput: Data? = nil) {
        self.paymaster = paymaster
        self.paymasterInput = paymasterInput
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let paymaster = paymaster {
            try container.encode(paymaster, forKey: .paymaster)
        }
        if let paymasterInput = paymasterInput {
            try container.encode(paymasterInput.bytes, forKey: .paymasterInput)
        }
    }
}
