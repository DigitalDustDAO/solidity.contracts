// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/* 
 This non-standard structure will keep track of the number of elements that exist and will
 always return the element with the least in existance. Ties will go to the element that has
 been at that count the longest. This structure is designed not to use searches (except when
 removing an item from consideration).

 Constraints: All items must be added to the tracking group or they will never be selected as 
 the smallest item. Items can be removed and re-added. Item totals can be tracked while they
 are not part of the tracking group, but they will never be selected as the smallest item.
 Each item can only move its total up or down one at a time. The list of items fits inside the
 range of a 64 bit unsigned integer. (If needed this can be increased to an 80 bit uint 
 without causing the ItemNode to use more than one solidity data block.) Item zero should not 
 be used. (If item zero is needed consider using +1 on all function calls.)
*/

abstract contract SizeSortedList {

    struct ItemNode {
        uint64 front;
        uint64 back;
        uint64 count;
        bool enabled;
    } // 56 bits unused

    mapping(uint256 => ItemNode) private itemCounts;
    mapping(uint256 => ItemNode) private totalOfCounts;

    function addItemToTrack(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];
        require(itemNumber != 0);

        if (!countNode.enabled) {
            _countNodeInsert(countNode, itemNumber);
            if (countNode.count < totalOfCounts[0].count) {
                totalOfCounts[0].count = countNode.count;
            }

            countNode.enabled = true;
        }
    }

    function removeItemFromTracking(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];

        if(_countNodeRemove(countNode, itemNumber) && totalOfCounts[0].count == countNode.count) {
            uint256 i = countNode.count + 1;
            while (totalOfCounts[i].front == 0) {
                i++;
            }

            totalOfCounts[0].count = uint64(i);
        }

        countNode.front = 0;
        countNode.back = 0;
        countNode.enabled = false;
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
        if (countNode.enabled) {
            _countNodeInsert(countNode, itemNumber);
        }
    }

    function decrementSizeList(uint64 itemNumber) internal {
        ItemNode storage countNode = itemCounts[itemNumber];
        require(countNode.count > 0, "Cannot reduce below 0 elements");

        _countNodeRemove(countNode, itemNumber);
        countNode.count--;
        
        if (countNode.enabled) {
            if (countNode.count < totalOfCounts[0].count) {
                totalOfCounts[0].count = countNode.count;
            }

            _countNodeInsert(countNode, itemNumber);
        }
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
