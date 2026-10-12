# Password Security in Databases

## Best Practices (Hashing & Salting)
Plaintext passwords should never be stored.
- **Hashing:** Using algorithms like *bcrypt* applies a heavy, slow, one-way function to plain passwords, creating a fingerprint. Its memory/CPU intensiveness deters brute-force attacks.
- **Salting:** Adding a unique random string (salt) for each user before hashing invalidates the use of pre-computed rainbow tables. Two users with the same password will not have the same hash because their salts will differ.

## Correlation with Dobar Ecosystem
- **SECURITY_IMPLEMENTATION.md:** We must enforce strict hashing + salting protocols. Currently, we use Firebase Auth for a lot of user authentication which manages this securely for us. 
- However, if any legacy or business portal systems require local password storage, we must standardise on **Bcrypt** or **Argon2**, ensuring a robust salt generation per user.
- **Data Breaches:** Following these practices safeguards our customers' and venues' trust, heavily aligning with our growth plans (BUSINESS_PLAN.md).
