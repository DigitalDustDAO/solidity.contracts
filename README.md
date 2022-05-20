# Some useful commands:

## Compiling
Compile all contracts
`npm run compile`

Display the size of every contract
`npm run size`

## Exporting ABI

Hardhat compiles ABI files with the contracts.  You can export the JSON files from their respective artifact directories into the longtail.social website repo, like so:

```
cp .\artifacts\contracts\SocialTokenNFT\LongTailSocialNFT.sol\LongTailSocialNFT.json ..\longtail.social\src\abi\
```

## Testing
Compile, then run all test suites
`npm run test`

Run all test suites (faster, but uses previously compiled contracts)
`npm run test-compile-none`

Only run one specific test (note: this has buggy output)
`npm run test .\test\DigitalDustDAO\DigitalDustDAO.test.js`

