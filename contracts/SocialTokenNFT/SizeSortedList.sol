// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract SizeSortedList {

    struct ItemNode {
        uint64 front;
        uint64 back;
        uint64 count;
    } // 64 bits unused

    mapping(uint256 => ItemNode) internal itemCounts;
    mapping(uint256 => ItemNode) internal totalOfCounts;

    function addItemToSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];
        require(countNode.count == 0, "Duplicate item"); 
        // ^ Not an all inclusive test that it doesn't already exist, but enough for a sanity check.

        _countNodeInsert(countNode, itemNumber);
        totalOfCounts[0].count = 0;
    }

    function removeItemFromSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];

        if(_countNodeRemove(countNode, itemNumber) && totalOfCounts[0].count == countNode.count) {
            uint256 i = countNode.count + 1;
            while (totalOfCounts[i].front == 0) {
                i++;
            }

            totalOfCounts[0].count = uint64(i);
        }
    }

    function incrementSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];

        if (totalOfCounts[0].count == countNode.count) {
            if (_countNodeRemove(countNode, itemNumber)) {
                totalOfCounts[0].count++;
            }
        }
        else {
            _countNodeRemove(countNode, itemNumber);
        }

        countNode.count++;
        _countNodeInsert(countNode, itemNumber);
    }

    function decrementSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];
        require(countNode.count > 0, "Cannot reduce below 0 elements");

        _countNodeRemove(countNode, itemNumber);
        countNode.count--;
        
        if (countNode.count < totalOfCounts[0].count) {
            totalOfCounts[0].count = countNode.count;
        }

        _countNodeInsert(countNode, itemNumber);
    }

    function getSizeListSmallestEntry() internal view returns(uint64 itemNumber) {
        itemNumber = totalOfCounts[totalOfCounts[0].count].back;
    }

    function _countNodeRemove(ItemNode storage countNode, uint64 itemNumber) private returns(bool listHasBeenEmptied) {
        ItemNode storage totalsNode = totalOfCounts[countNode.count];

        if (totalsNode.front == itemNumber) {
            if (totalsNode.back == itemNumber) {
                totalOfCounts[countNode.count].front = 0;
                totalOfCounts[countNode.count].back = 0;
                return true;
            }

            totalsNode.front = countNode.back;
            itemCounts[countNode.back].front = countNode.front;
        }
        else if (totalsNode.back == itemNumber) {
            totalsNode.back = countNode.front;
            itemCounts[countNode.front].back = countNode.back;
        }
        else {
            itemCounts[countNode.front].back = countNode.back;
            itemCounts[countNode.back].front = countNode.front;
        }

        return false;
    }

    function _countNodeInsert(ItemNode storage countNode, uint64 itemNumber) private {
        ItemNode storage totalsNode = totalOfCounts[countNode.count];

        if (totalsNode.front == 0) {
            countNode.front = 0;
            countNode.back = 0;
            totalsNode.front = itemNumber;
            totalsNode.back = itemNumber;
        }
        else {
            itemCounts[totalsNode.front].front = itemNumber;
            countNode.front = 0;
            countNode.back = totalsNode.front;
            totalsNode.front = itemNumber;
        }
    }
}
