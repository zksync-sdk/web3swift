//
//  TransactionReceipt.swift
//
//
//  Created by Yaroslav Yashin on 12.07.2022.
//

import Foundation
import BigInt

public struct TransactionReceipt {
    public var transactionHash: Data
    public var blockHash: Data
    public var l1BatchNumber: BigUInt?
    public var l1BatchTxIndex: UInt?
    public var blockNumber: BigUInt
    public var transactionIndex: BigUInt
    public var contractAddress: EthereumAddress?
    public var cumulativeGasUsed: BigUInt
    public var gasUsed: BigUInt
    public var effectiveGasPrice: BigUInt
    public var logs: [EventLog]
    public var l2ToL1Logs: [L2ToL1Log]?
    public var status: TXStatus
    public var logsBloom: EthereumBloomFilter?

    static func notProcessed(transactionHash: Data) -> TransactionReceipt {
        TransactionReceipt(transactionHash: transactionHash, blockHash: Data(), l1BatchNumber: BigUInt(0), l1BatchTxIndex: 0, blockNumber: 0, transactionIndex: 0, contractAddress: nil, cumulativeGasUsed: 0, gasUsed: 0, effectiveGasPrice: 0, logs: [], l2ToL1Logs: nil, status: .notYetProcessed, logsBloom: nil)
    }
}

extension TransactionReceipt {
    public enum TXStatus {
        case ok
        case failed
        case notYetProcessed
    }
}

extension TransactionReceipt: Decodable {
    enum CodingKeys: String, CodingKey {
        case blockHash
        case l1BatchNumber
        case l1BatchTxIndex
        case blockNumber
        case transactionHash
        case transactionIndex
        case contractAddress
        case cumulativeGasUsed
        case gasUsed
        case logs
        case l2ToL1Logs
        case logsBloom
        case status
        case effectiveGasPrice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.blockNumber = try container.decodeHex(BigUInt.self, forKey: .blockNumber)
        
        self.l1BatchNumber = try container.decodeHexIfPresent(BigUInt.self, forKey: .l1BatchNumber)
        
        self.l1BatchTxIndex = try container.decodeHexIfPresent(UInt.self, forKey: .l1BatchTxIndex)

        self.blockHash = try container.decodeHex(Data.self, forKey: .blockHash)

        self.transactionIndex = try container.decodeHex(BigUInt.self, forKey: .transactionIndex)

        self.transactionHash = try container.decodeHex(Data.self, forKey: .transactionHash)

        self.contractAddress = try? container.decodeIfPresent(EthereumAddress.self, forKey: .contractAddress)

        self.cumulativeGasUsed = try container.decodeHex(BigUInt.self, forKey: .cumulativeGasUsed)

        self.gasUsed = try container.decodeHex(BigUInt.self, forKey: .gasUsed)

        self.effectiveGasPrice = (try? container.decodeHex(BigUInt.self, forKey: .effectiveGasPrice)) ?? 0

        let status = try? container.decodeHex(BigUInt.self, forKey: .status)
        switch status {
        case nil: self.status = .notYetProcessed
        case 1: self.status = .ok
        default: self.status = .failed
        }

        self.logs = try container.decode([EventLog].self, forKey: .logs)
        
        self.l2ToL1Logs = try? container.decodeIfPresent([L2ToL1Log].self, forKey: .l2ToL1Logs)

        if let hexBytes = try? container.decodeHex(Data.self, forKey: .logsBloom) {
            self.logsBloom = EthereumBloomFilter(hexBytes)
        }
    }
}

public struct L2ToL1Log: Decodable {
    
    public let blockNumber: BigUInt
    
    public let blockHash: Data
    
    public let l1BatchNumber: BigUInt
    
    public let transactionIndex: UInt
    
    public let shardId: UInt
    
    public let isService: Bool
    
    public let sender: EthereumAddress
    
    public let key: String
    
    public let value: String
    
    public let transactionHash: String
    
    public let logIndex: UInt
    
    enum CodingKeys: String, CodingKey {
        case blockNumber
        case blockHash
        case l1BatchNumber
        case transactionIndex
        case shardId
        case isService
        case sender
        case key
        case value
        case transactionHash
        case logIndex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.blockNumber = try container.decodeHex(BigUInt.self, forKey: .blockNumber)
        self.blockHash = try container.decodeHex(Data.self, forKey: .blockHash)
        self.l1BatchNumber = try container.decodeHex(BigUInt.self, forKey: .l1BatchNumber)
        self.transactionIndex = try container.decodeHex(UInt.self, forKey: .transactionIndex)
        self.shardId = try container.decodeHex(UInt.self, forKey: .shardId)
        self.isService = try container.decode(Bool.self, forKey: .isService)
        self.sender = try container.decode(EthereumAddress.self, forKey: .sender)
        self.key = try container.decode(String.self, forKey: .key)
        self.value = try container.decode(String.self, forKey: .value)
        self.transactionHash = try container.decode(String.self, forKey: .transactionHash)
        self.logIndex = try container.decodeHex(UInt.self, forKey: .logIndex)
    }
}

extension TransactionReceipt: APIResultType { }
