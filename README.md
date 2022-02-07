#Some useful commands:

##Compiling
Compile all contracts
`npx truffle compile`

Display the size of every contract
`npx truffle run contract-size`

Ignore the mock contracts
`npx truffle run contract-size --ignoreMocks`

Display the size of specific contracts
`npx truffle run contract-size --contracts LongTailSocialToken`

##Testing
Compile, then run all test suites
`npx truffle test`

Run all test suites (faster, but uses previously compiled contracts)
`npx truffle test --compile-none`

Only run one specific test
`npx truffle test .\test\DigitalDustDAO\DigitalDustDAO.test.js`

