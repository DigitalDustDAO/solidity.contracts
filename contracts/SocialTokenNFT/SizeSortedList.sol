// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract SizeSortedList {

    struct ItemNode {
        uint64 unused;
        uint64 front;
        uint64 back;
        uint64 count;
    }

    mapping(uint256 => ItemNode) private itemCounts;
    mapping(uint256 => ItemNode) private indexOfCounts;

    function addItemToSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];
        require(countNode.count == 0, "Duplicate item"); // Not an all inclusive test that it doesn't already exist, but enough for a sanity check.

        _countNodeInsert(countNode, itemNumber);
        indexOfCounts[0].count = 0;
    }

    function incrementSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];

        if (indexOfCounts[0].count == countNode.count) {
            if (_countNodeRemove(countNode, itemNumber)) {
                indexOfCounts[0].count++;
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

        if (indexOfCounts[0].count == countNode.count) {
            if (_countNodeRemove(countNode, itemNumber)) {
                indexOfCounts[0].count--;
            }
        }
        else {
            _countNodeRemove(countNode, itemNumber);
        }

        countNode.count--;
        _countNodeInsert(countNode, itemNumber);
    }

    function getSizeListSmallestEntry() internal view returns(uint64 itemNumber) {
        itemNumber = indexOfCounts[indexOfCounts[0].count].back;
    }

    function _countNodeRemove(ItemNode storage countNode, uint64 itemNumber) private returns(bool listHasBeenEmptied) {
        ItemNode storage groupList = indexOfCounts[countNode.count];

        if (groupList.front == itemNumber) {
            if (groupList.back == itemNumber) {
                delete(indexOfCounts[countNode.count]);
                return true;
            }

            groupList.front = countNode.back;
            itemCounts[countNode.back].front = countNode.front;
        }
        else if (groupList.back == itemNumber) {
            groupList.back = countNode.front;
            itemCounts[countNode.front].back = countNode.back;
        }
        else {
            itemCounts[countNode.front].back = countNode.back;
            itemCounts[countNode.back].front = countNode.front;
        }

        return false;
    }

    function _countNodeInsert(ItemNode storage countNode, uint64 itemNumber) private {
        ItemNode storage groupList = indexOfCounts[countNode.count];

        if (groupList.front == 0) {
            countNode.front = 0;
            countNode.back = 0;
            groupList.front = itemNumber;
            groupList.back = itemNumber;
        }
        else {
            itemCounts[groupList.front].front = itemNumber;
            countNode.front = 0;
            countNode.back = groupList.front;
            groupList.front = itemNumber;
        }
    }

}