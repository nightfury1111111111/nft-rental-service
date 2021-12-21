# Car Rental

This set of contracts is about renting a car for a specific period. I have used the Remix IDE to edit and deploy the contracts.

By Deploying the RentalCar.sol you can mint a new rental car token (CRT) with some hourly rent price. A guest user can then reserve your CRT token providing the rent duration in Unix time and the rent price. Rent price is calculated as no of hours * hourly rent price of the CRT token.

Go through [this blog](https://leather-vinca-729.notion.site/NFT-Renting-3621fcb5e01a4d9a837f523212683223) for a detailed explaination.