//
//  EIP712Envelope.swift
//
//
//  Created by Petar Kopestinskij on 27.2.24..
//

import Foundation
import BigInt

public struct EIP712Envelope: EIP2718Envelope {
    public let type: TransactionType = .eip712
    
    // common parameters for any transaction
    public var nonce: BigUInt = 0
    public var chainID: BigUInt?
    public var to: EthereumAddress
    public var value: BigUInt
    public var data: Data
    public var v: BigUInt
    public var r: BigUInt
    public var s: BigUInt
    
    // EIP-1559 specific parameters
    public var gasLimit: BigUInt
    /// Value of the tip to the miner for transaction processing.
    ///
    /// Full amount of this variable goes to a miner.
    public var maxPriorityFeePerGas: BigUInt?
    
    /// Value of the fee for one gas unit
    ///
    /// This value should be greater than sum of:
    /// - `Block.nextBlockBaseFeePerGas` - baseFee which will be burnt during the transaction processing
    /// - `self.maxPriorityFeePerGas` - explicit amount of a tip to the miner of the given block which will include this transaction
    ///
    /// If amount of this will be **greater** than sum of `Block.baseFeePerGas` and `maxPriorityFeePerGas`
    /// all exceed funds will be returned to the sender.
    ///
    /// If amount of this will be **lower** than sum of `Block.baseFeePerGas` and `maxPriorityFeePerGas`
    /// miner will recieve amount calculated by the following equation: `maxFeePerGas - Block.baseFeePerGas`
    /// where 'Block' is the block that the transaction will be included.
    public var maxFeePerGas: BigUInt?
    
    public var gasPrice: BigUInt?
    
    public var accessList: [AccessListEntry] // from EIP-2930

    public var from: EthereumAddress?

    public var eip712Meta: EIP712Meta?

    // for CustomStringConvertible
    public var description: String {
        var toReturn = ""
        toReturn += "Type: " + String(describing: self.type) + "\n"
        toReturn += "chainID: " + String(describing: self.chainID) + "\n"
        toReturn += "Nonce: " + String(describing: self.nonce) + "\n"
        toReturn += "Gas limit: " + String(describing: self.gasLimit) + "\n"
        toReturn += "Max priority fee per gas: " + String(describing: self.maxPriorityFeePerGas) + "\n"
        toReturn += "Max fee per gas: " + String(describing: maxFeePerGas) + "\n"
        toReturn += "To: " + self.to.address + "\n"
        toReturn += "Value: " + String(describing: self.value) + "\n"
        toReturn += "Data: " + self.data.toHexString().addHexPrefix().lowercased() + "\n"
        toReturn += "Access List: " + String(describing: accessList) + "\n"
        toReturn += "v: " + String(self.v) + "\n"
        toReturn += "r: " + String(self.r) + "\n"
        toReturn += "s: " + String(self.s) + "\n"
        return toReturn
    }
}

extension EIP712Envelope {

    private enum CodingKeys: String, CodingKey {
        case chainId
        case nonce
        case to
        case value
        case maxPriorityFeePerGas
        case maxFeePerGas
        case gasLimit
        case gas
        case data
        case input
        case accessList
        case v
        case r
        case s
    }

    public init?(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard container.contains(.to), container.contains(.nonce), container.contains(.value), container.contains(.chainId) else { return nil }
        if !container.contains(.data) && !container.contains(.input) { return nil }
        guard container.contains(.v), container.contains(.r), container.contains(.s) else { return nil }

        // everything we need is present, so we should only have to throw from here
        self.chainID = try container.decodeHexIfPresent(BigUInt.self, forKey: .chainId) ?? 0
        self.nonce = try container.decodeHex(BigUInt.self, forKey: .nonce)

        let list = try? container.decode([AccessListEntry].self, forKey: .accessList)
        self.accessList = list ?? []

        let toString = try? container.decode(String.self, forKey: .to)
        switch toString {
        case nil, "0x", "0x0":
            self.to = EthereumAddress.contractDeploymentAddress()
        default:
            // the forced unwrap here is safe as we trap nil in the previous case
            // swiftlint:disable force_unwrapping
            guard let ethAddr = EthereumAddress(toString!) else { throw Web3Error.dataError }
            // swiftlint:enable force_unwrapping
            self.to = ethAddr
        }

        self.value = try container.decodeHexIfPresent(BigUInt.self, forKey: .value) ?? 0
        self.maxPriorityFeePerGas = try container.decodeHexIfPresent(BigUInt.self, forKey: .maxPriorityFeePerGas) ?? 0
        self.maxFeePerGas = try container.decodeHexIfPresent(BigUInt.self, forKey: .maxFeePerGas) ?? 0
        self.gasLimit = try container.decodeHexIfPresent(BigUInt.self, forKey: .gas) ?? container.decodeHexIfPresent(BigUInt.self, forKey: .gasLimit) ?? 0

        self.data = try container.decodeHexIfPresent(Data.self, forKey: .input) ?? container.decodeHex(Data.self, forKey: .data)
        self.v = try container.decodeHex(BigUInt.self, forKey: .v)
        self.r = try container.decodeHex(BigUInt.self, forKey: .r)
        self.s = try container.decodeHex(BigUInt.self, forKey: .s)
    }

    private enum RlpKey: Int, CaseIterable {
        case nonce
        case maxPriorityFeePerGas
        case maxFeePerGas
        case gasLimit
        case to
        case value
        case data
        case chainID1
        case undefined1
        case undefined2
        case chainID2
        case from
        case gasPerPubdata
        case factoryDeps
        case customSignature
        case paymasterParams
    }

    public init?(rawValue: Data) {
        // pop the first byte from the stream [EIP-2718]
        let typeByte: UInt8 = rawValue.first ?? 0 // can't decode if we're the wrong type
        guard self.type.rawValue == typeByte else { return nil }

        guard let totalItem = RLP.decode(rawValue.dropFirst(1)) else { return nil }
        guard let rlpItem = totalItem[0] else { return nil }
        guard RlpKey.allCases.count == rlpItem.count else { return nil }

        // we've validated the item count, so rlpItem[keyName] is guaranteed to return something not nil
        // swiftlint:disable force_unwrapping
        guard let chain1Data = rlpItem[RlpKey.chainID1.rawValue]!.data else { return nil }
        guard let chain2Data = rlpItem[RlpKey.chainID2.rawValue]!.data else { return nil }
        guard let nonceData = rlpItem[RlpKey.nonce.rawValue]!.data else { return nil }
        guard let maxPriorityData = rlpItem[RlpKey.maxPriorityFeePerGas.rawValue]!.data else { return nil }
        guard let maxFeeData = rlpItem[RlpKey.maxFeePerGas.rawValue]!.data else { return nil }
        guard let gasLimitData = rlpItem[RlpKey.gasLimit.rawValue]!.data else { return nil }
        guard let valueData = rlpItem[RlpKey.value.rawValue]!.data else { return nil }
        guard let transactionData = rlpItem[RlpKey.data.rawValue]!.data else { return nil }
        guard let signature = rlpItem[RlpKey.customSignature.rawValue]!.data else { return nil }
        guard let unmarshalledSignature = SECP256K1.unmarshalSignature(signatureData: signature) else { return nil }
        let rData = unmarshalledSignature.r
        let sData = unmarshalledSignature.s
        let vData = unmarshalledSignature.v

        // swiftlint:enable force_unwrapping

        self.chainID = BigUInt(chain1Data)
        self.chainID = BigUInt(chain2Data)
        self.nonce = BigUInt(nonceData)
        self.maxPriorityFeePerGas = BigUInt(maxPriorityData)
        self.maxFeePerGas = BigUInt(maxFeeData)
        self.gasLimit = BigUInt(gasLimitData)
        self.value = BigUInt(valueData)
        self.data = transactionData
        self.r = BigUInt(rData)
        self.s = BigUInt(sData)
        self.v = BigUInt(vData)

        var factoryDeps: [Data] = []
        switch rlpItem[RlpKey.factoryDeps.rawValue]!.content {
            // swiftlint:enable force_unwrapping
        case .noItem:
            factoryDeps = []
        case .data:
            factoryDeps = []
        case .list:
            // decode the list here
            // swiftlint:disable force_unwrapping
            let keyData = rlpItem[RlpKey.factoryDeps.rawValue]!
            // swiftlint:enable force_unwrapping
            let itemCount = keyData.count ?? 0
            var newList: [Data] = []
            for index in 0...(itemCount - 1) {
                guard let keyItem = keyData[index] else { return nil }
                guard let itemData = keyItem.data else { return nil }
                let newItem = itemData
                newList.append(newItem)
            }
            factoryDeps = newList
        }

        var gasPerPubdata: BigUInt?
        if let data = rlpItem[RlpKey.gasPerPubdata.rawValue]?.data {
            gasPerPubdata = BigUInt(data)
        }
        let customSignature = rlpItem[RlpKey.customSignature.rawValue]?.data

        var paymasterParams: PaymasterParams?
        switch rlpItem[RlpKey.paymasterParams.rawValue]!.content {
            // swiftlint:enable force_unwrapping
        case .noItem:
            paymasterParams = nil
        case .data:
            paymasterParams = nil
        case .list:
            // decode the list here
            // swiftlint:disable force_unwrapping
            let keyData = rlpItem[RlpKey.paymasterParams.rawValue]!
            // swiftlint:enable force_unwrapping
            let itemCount = keyData.count ?? 0
            var paymasterAddress: EthereumAddress?
            var paymasterInput: Data?
            for index in 0...(itemCount - 1) {
                guard let keyItem = keyData[index] else { return nil }
                guard let itemData = keyItem.data else { return nil }
                let newItem = itemData

                if newItem.count == 20 {
                    guard let addr = EthereumAddress(newItem) else { return nil }
                    paymasterAddress = addr
                } else {
                    paymasterInput = newItem
                }
            }

            paymasterParams = PaymasterParams(paymaster: paymasterAddress, paymasterInput: paymasterInput)
        }

        self.eip712Meta = Web3Core.EIP712Meta(gasPerPubdata: gasPerPubdata, customSignature: customSignature, paymasterParams: paymasterParams, factoryDeps: factoryDeps)

        switch rlpItem[RlpKey.from.rawValue]!.content {
            // swiftlint:enable force_unwrapping
        case .noItem:
            self.from = nil
        case .data(let addressData):
            if addressData.count == 0 {
                self.from = nil
            } else if addressData.count == 20 {
                guard let addr = EthereumAddress(addressData) else { return nil }
                self.from = addr
            } else { return nil }
        case .list:
            return nil
        }

        // swiftlint:disable force_unwrapping
        switch rlpItem[RlpKey.to.rawValue]!.content {
            // swiftlint:enable force_unwrapping
        case .noItem:
            self.to = EthereumAddress.contractDeploymentAddress()
        case .data(let addressData):
            if addressData.count == 0 {
                self.to = EthereumAddress.contractDeploymentAddress()
            } else if addressData.count == 20 {
                guard let addr = EthereumAddress(addressData) else { return nil }
                self.to = addr
            } else { return nil }
        case .list:
            return nil
        }

        self.accessList = []
    }

    public init(to: EthereumAddress,
                nonce: BigUInt? = nil,
                v: BigUInt = 1,
                r: BigUInt = 0,
                s: BigUInt = 0,
                chainID: BigUInt? = nil,
                value: BigUInt? = nil,
                data: Data? = nil,
                maxPriorityFeePerGas: BigUInt? = nil,
                maxFeePerGas: BigUInt? = nil,
                gasLimit: BigUInt? = nil,
                gasPrice: BigUInt? = nil,
                accessList: [AccessListEntry]? = nil,
                from: EthereumAddress? = nil,
                eip712Meta: EIP712Meta? = nil) {
        self.to = to
        self.nonce = nonce ?? 0
        self.chainID = chainID ?? 0
        self.value = value ?? 0
        self.data =  data ?? Data()
        self.v = v
        self.r = r
        self.s = s
        self.maxPriorityFeePerGas = maxPriorityFeePerGas ?? 0
        self.maxFeePerGas = maxFeePerGas ?? 0
        self.gasLimit = gasLimit ?? 0
        self.gasPrice = gasPrice ?? 0
        self.accessList = accessList ?? []
        self.from = from
        self.eip712Meta = eip712Meta
    }

    // memberwise
    public init(to: EthereumAddress,
                nonce: BigUInt = 0,
                chainID: BigUInt = 0,
                value: BigUInt = 0,
                data: Data,
                maxPriorityFeePerGas: BigUInt = 0,
                maxFeePerGas: BigUInt = 0,
                gasLimit: BigUInt = 0,
                accessList: [AccessListEntry]? = nil,
                v: BigUInt = 1,
                r: BigUInt = 0,
                s: BigUInt = 0) {
        self.to = to
        self.nonce = nonce
        self.chainID = chainID
        self.value = value
        self.data = data
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.maxFeePerGas = maxFeePerGas
        self.gasLimit = gasLimit
        self.accessList = accessList ?? []
        self.v = v
        self.r = r
        self.s = s
    }

    public func encode(for type: EncodeType = .transaction) -> Data? {
        var fields: [AnyObject]

        switch type {
        case .transaction:
            fields = [
                nonce, // 0
                maxPriorityFeePerGas, // 1
                maxFeePerGas, // 2
                gasLimit, // 3
                to.addressData, // 4
                value, // 5
                data, // 6
                chainID, // 7
                "", // 8
                "", // 9
                chainID // 10
            ] as [AnyObject]

            print("[EIP712 encoder] transactionType: \(BigUInt(UInt8(self.type.rawValue)).data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] nonce: \(nonce.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] maxPriorityFeePerGas: \(maxPriorityFeePerGas?.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] maxFeePerGas: \(maxFeePerGas?.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] gasLimit: \(gasLimit.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] to: \(to.addressData.toHexString().addHexPrefix())")
            print("[EIP712 encoder] value: \(value.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] data: \(data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] chainID: \(chainID?.data.toHexString().addHexPrefix())")
            print("[EIP712 encoder] empty string: \("".data(using: .utf8)!.toHexString().addHexPrefix())")
            print("[EIP712 encoder] empty string: \("".data(using: .utf8)!.toHexString().addHexPrefix())")
            print("[EIP712 encoder] chainID: \(chainID?.data.toHexString().addHexPrefix())")

            // 11
            if let from = from?.addressData {
                print("[EIP712 encoder] from: \(from.toHexString().addHexPrefix())")
                fields.append(from as AnyObject)
            } else {
                fields.append(Data() as AnyObject)
            }

            // 12
            if let gasPerPubdata = eip712Meta?.gasPerPubdata {
                print("[EIP712 encoder] gasPerPubdata: \(gasPerPubdata.data.toHexString().addHexPrefix())")
                fields.append(gasPerPubdata as AnyObject)
            } else {
                fields.append(BigUInt(0) as AnyObject)
            }

            // 13
            if let factoryDeps = eip712Meta?.factoryDeps {
                factoryDeps.forEach {
                    print("[EIP712 encoder] factoryDeps: \($0.toHexString().addHexPrefix())")
                }

                fields.append(factoryDeps as AnyObject)
            } else {
                fields.append([] as AnyObject)
            }

            // 14
            if let customSignature = eip712Meta?.customSignature {
                fields.append(customSignature as AnyObject)
            } else {
                var customSignature = Data()
                customSignature.append(r.data)
                customSignature.append(s.data)
                customSignature.append(v.data)

                fields.append(customSignature as AnyObject)
            }

            // 15
            if let paymasterParams = eip712Meta?.paymasterParams, let paymaster = paymasterParams.paymaster, let paymasterInput = paymasterParams.paymasterInput {
                fields.append([paymaster.addressData, paymasterInput] as AnyObject)
            } else {
                fields.append([] as AnyObject)
            }
        case .signature:
            fields = [
                nonce,
                maxPriorityFeePerGas,
                maxFeePerGas,
                gasLimit,
                to.addressData,
                from?.address,
                value,
                data,
                chainID,
                gasPrice,
                accessList,
                eip712Meta
            ] as [AnyObject]
        }
        guard var result = RLP.encode(fields) else { return nil }
        result.insert(UInt8(self.type.rawValue), at: 0)
        return result
    }
}
