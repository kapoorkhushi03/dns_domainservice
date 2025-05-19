module dns::domainservice {
    // Importing necessary Sui modules
    use sui::object; // For UID and object creation
    use sui::transfer; // For sharing and transferring objects
    use sui::tx_context; // For transaction context (sender, IDs)
    use sui::table::{Self, Table}; // For key-value storage
    use sui::coin; // For coin operations (split, transfer)
    use sui::sui::SUI; // For SUI coin type
    use std::string::String; // For string handling
    use sui::balance::{Self, Balance}; // For managing SUI balance
    use sui::event; // For emitting events
    use sui::clock::{Self, Clock}; // For timestamp

    // Error codes (immutable constants)
    const EIPAlreadyExists: u64 = 0; // IP already registered
    const EDomainAlreadyExists: u64 = 2; // Domain already registered
    const EDomainNotFound: u64 = 3; // Domain not found
    const EInsufficientFunds: u64 = 4; // Payment too low
    const ENotDomainOwner: u64 = 5; // Sender not owner
    const EAlreadyOwner: u64 = 6; // Buyer is already owner
    const ENotAdmin: u64 = 7; // Sender not admin

    // Domain price (immutable constant)
    const DOMAIN_PRICE: u64 = 1_000_000_000; // 1 SUI

    // Admin address (immutable; replace before deployment)
    const ADMIN: address = @0x123;

    // IP address record
    // - store: Allows storage in Table
    // - drop: Allows removal in tests
    public struct IPRecord has store, drop {
        ip_address: String, // IP address (e.g., "192.168.1.1")
        website_code: String, // Website content (e.g., "<html>test</html>")
        owner: address, // Owner address
    }

    // Domain record
    // - store: Allows storage in Table
    // - drop: Allows removal in tests
    public struct DomainRecord has store, drop {
        domain_name: String, // Domain (e.g., "example.com")
        ip_address: String, // Linked IP address
        owner: address, // Owner address
        expiry_time: u64, // Expiry timestamp (ms)
    }

    // IP registry (shared object)
    // - key, store: Allows on-chain storage and sharing
    public struct IPRegistry has key, store {
        id: object::UID, // Unique ID
        ips: Table<String, IPRecord>, // Maps IP address to IPRecord
    }

    // Domain registry (shared object)
    // - key, store: Allows on-chain storage and sharing
    public struct DomainRegistry has key, store {
        id: object::UID, // Unique ID
        domains: Table<String, DomainRecord>, // Maps domain to DomainRecord
        fee_balance: Balance<SUI>, // Collected fees
    }

    // Events for logging actions
    // - copy, drop: Allows emission and discarding
    public struct IPAllotted has copy, drop {
        ip_address: String,
        owner: address,
    }

    public struct DomainAssigned has copy, drop {
        domain_name: String,
        ip_address: String,
        owner: address,
        expiry_time: u64,
    }

    public struct DomainPurchased has copy, drop {
        domain_name: String,
        new_owner: address,
        price: u64,
    }

    // Initialize shared registries
    // - ctx: mutable for object ID creation
    fun init(ctx: &mut tx_context::TxContext) {
        // Create IPRegistry with empty table
        let ip_registry = IPRegistry {
            id: object::new(ctx), // Mutable ctx for new ID
            ips: table::new(ctx), // Empty table
        };

        // Create DomainRegistry with empty table and zero balance
        let domain_registry = DomainRegistry {
            id: object::new(ctx),
            domains: table::new(ctx),
            fee_balance: balance::zero(), // Immutable zero balance
        };

        // Share objects (immutable after sharing)
        transfer::share_object(ip_registry);
        transfer::share_object(domain_registry);
    }

    // Register an IP address
    // - ip_registry: mutable to add to ips table
    // - ip_address, website_code, owner: immutable inputs
    // - _ctx: mutable but unused (kept for consistency)
    public entry fun allot_ip(
        ip_registry: &mut IPRegistry,
        ip_address: String,
        website_code: String,
        owner: address,
        _ctx: &mut tx_context::TxContext
    ) {
        // Check if IP exists (immutable borrow)
        assert!(!table::contains(&ip_registry.ips, ip_address), EIPAlreadyExists);

        // Create immutable IPRecord
        let ip_record = IPRecord {
            ip_address,
            website_code,
            owner,
        };

        // Add to table (mutable borrow)
        table::add(&mut ip_registry.ips, ip_address, ip_record);

        // Emit event (immutable)
        event::emit(IPAllotted { ip_address, owner });
    }

    // Assign a domain to an owner
    // - ip_registry, domain_registry: mutable for updates
    // - domain_name, ip_address, website_code, owner: immutable inputs
    // - clock: immutable for timestamp
    // - ctx: mutable for allot_ip
    public entry fun assign_domain(
        ip_registry: &mut IPRegistry,
        domain_registry: &mut DomainRegistry,
        domain_name: String,
        ip_address: String,
        website_code: String,
        owner: address,
        clock: &Clock,
        ctx: &mut tx_context::TxContext
    ) {
        // Check if domain exists
        assert!(!table::contains(&domain_registry.domains, domain_name), EDomainAlreadyExists);

        // Add IP if not exists
        if (!table::contains(&ip_registry.ips, ip_address)) {
            allot_ip(ip_registry, ip_address, website_code, owner, ctx);
        };

        // Set expiry to 1 year from now
        let expiry_time = clock::timestamp_ms(clock) + 365 * 24 * 60 * 60 * 1000;

        // Create immutable DomainRecord
        let domain_record = DomainRecord {
            domain_name,
            ip_address,
            owner,
            expiry_time,
        };

        // Add to table
        table::add(&mut domain_registry.domains, domain_name, domain_record);

        // Emit event
        event::emit(DomainAssigned {
            domain_name,
            ip_address,
            owner,
            expiry_time,
        });
    }

    // Buy a domain (transfer ownership)
    // - domain_registry: mutable for domains and fee_balance
    // - domain_name: immutable input
    // - payment: mutable for coin::split and transfer
    // - ctx: mutable for sender and split
   public entry fun buy_domain(
    domain_registry: &mut DomainRegistry,
    domain_name: String,
    mut payment: coin::Coin<SUI>, // Add 'mut' here
    ctx: &mut tx_context::TxContext
) {
        // Check if domain exists
        assert!(table::contains(&domain_registry.domains, domain_name), EDomainNotFound);

        // Check if buyer is not owner
        let domain_record = table::borrow(&domain_registry.domains, domain_name);
        assert!(domain_record.owner != tx_context::sender(ctx), EAlreadyOwner);

        // Check payment amount
        let payment_value = coin::value(&payment);
        assert!(payment_value >= DOMAIN_PRICE, EInsufficientFunds);

        // Split exact payment (requires mutable payment)
        let paid = coin::split(&mut payment, DOMAIN_PRICE, ctx);

        // Add to fee balance
        let paid_balance = coin::into_balance(paid);
        balance::join(&mut domain_registry.fee_balance, paid_balance);

        // Refund remaining payment or destroy if zero
        if (coin::value(&payment) > 0) {
            transfer::public_transfer(payment, tx_context::sender(ctx));
        } else {
            coin::destroy_zero(payment); // Drop zero-value coin
        };

        // Update owner (mutable borrow)
        let domain_record = table::borrow_mut(&mut domain_registry.domains, domain_name);
        domain_record.owner = tx_context::sender(ctx);

        // Emit event
        event::emit(DomainPurchased {
            domain_name,
            new_owner: tx_context::sender(ctx),
            price: DOMAIN_PRICE,
        });
    }

    // Transfer domain ownership
    // - domain_registry: mutable for owner update
    // - domain_name, new_owner: immutable inputs
    // - ctx: mutable for sender
    public entry fun transfer_domain(
        domain_registry: &mut DomainRegistry,
        domain_name: String,
        new_owner: address,
        ctx: &mut tx_context::TxContext
    ) {
        // Check if domain exists
        assert!(table::contains(&domain_registry.domains, domain_name), EDomainNotFound);

        // Check if sender is owner
        let domain_record = table::borrow_mut(&mut domain_registry.domains, domain_name);
        assert!(domain_record.owner == tx_context::sender(ctx), ENotDomainOwner);

        // Update owner
        domain_record.owner = new_owner;
    }

    // Withdraw fees (admin only)
    // - domain_registry: mutable for fee_balance
    // - amount, recipient: immutable inputs
    // - ctx: mutable for sender and coin creation
    public entry fun withdraw_fees(
        domain_registry: &mut DomainRegistry,
        amount: u64,
        recipient: address,
        ctx: &mut tx_context::TxContext
    ) {
        // Check if sender is admin
        assert!(tx_context::sender(ctx) == ADMIN, ENotAdmin);

        // Check balance
        let current_balance = balance::value(&domain_registry.fee_balance);
        assert!(current_balance >= amount, EInsufficientFunds);

        // Split and transfer funds
        let withdrawn = coin::from_balance(balance::split(&mut domain_registry.fee_balance, amount), ctx);
        transfer::public_transfer(withdrawn, recipient);
    }
    public fun read_domain(
        ip_registry: &IPRegistry,
        domain_registry: &DomainRegistry,
        domain_name: String,
        clock: &Clock
    ): (address, String, u64) {
        assert!(table::contains(&domain_registry.domains, domain_name), EDomainNotFound);
        let domain_record = table::borrow(&domain_registry.domains, domain_name);
        assert!(domain_record.expiry_time > clock::timestamp_ms(clock), EDomainNotFound);
        assert!(table::contains(&ip_registry.ips, domain_record.ip_address), EDomainNotFound);
        let ip_record = table::borrow(&ip_registry.ips, domain_record.ip_address);
        (domain_record.owner, ip_record.website_code, domain_record.expiry_time)
    }

    // Test-only functions for creating registries
    #[test_only]
    public fun create_test_ip_registry(ctx: &mut tx_context::TxContext): IPRegistry {
        IPRegistry {
            id: object::new(ctx),
            ips: table::new(ctx)
        }
    }

    #[test_only]
    public fun create_test_domain_registry(ctx: &mut tx_context::TxContext): DomainRegistry {
        DomainRegistry {
            id: object::new(ctx),
            domains: table::new(ctx),
            fee_balance: balance::zero()
        }
    }

    // Test-only functions for clearing registries
    #[test_only]
    public fun clear_test_ip_registry(ip_registry: &mut IPRegistry, ip_address: String) {
        if (table::contains(&ip_registry.ips, ip_address)) {
            let _ = table::remove(&mut ip_registry.ips, ip_address); // IPRecord dropped
        };
    }

    #[test_only]
    public fun clear_test_domain_registry(domain_registry: &mut DomainRegistry, domain_name: String) {
        if (table::contains(&domain_registry.domains, domain_name)) {
            let _ = table::remove(&mut domain_registry.domains, domain_name); // DomainRecord dropped
        };
    }

    // Test-only functions for destroying registries
    #[test_only]
    public fun destroy_test_ip_registry(ip_registry: IPRegistry) {
        let IPRegistry { id, ips } = ip_registry;
        table::destroy_empty(ips);
        object::delete(id);
    }

    #[test_only]
    public fun destroy_test_domain_registry(domain_registry: DomainRegistry) {
        let DomainRegistry { id, domains, fee_balance } = domain_registry;
        table::destroy_empty(domains);
        balance::destroy_for_testing(fee_balance);
        object::delete(id);
    }
}