
library Coin {
    function toShares(
        uint256 coins,
        uint256 totalShares,
        uint256 totalCoins
    ) internal pure returns (uint256) {
        if (totalCoins > 0) {
            return coins * totalShares / totalCoins;
        } else {
            return 0;
        }
    }
}
