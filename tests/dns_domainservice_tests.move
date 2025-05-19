#[test_only]
module dns::domainservice_tests {
    use sui::test_scenario;
    use std::string;
    use dns::domainservice;
    use sui::clock;
    use sui::coin;
    use sui::sui::SUI;

    #[test]
    fun test_domain_assignment() {
        let mut scenario_val = test_scenario::begin(@0x123);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);
        let mut clock = clock::create_for_testing(ctx);

        // Create objects
        let mut ip_registry = domainservice::create_test_ip_registry(ctx);
        let mut domain_registry = domainservice::create_test_domain_registry(ctx);

        // Assign a domain
        domainservice::assign_domain(
            &mut ip_registry,
            &mut domain_registry,
            string::utf8(b"example.com"),
            string::utf8(b"192.168.1.1"),
            string::utf8(b"<html>test</html>"),
            @0x123,
            &clock,
            ctx
        );

        // Verify the domain assignment
        let (owner, website_code, expiry_time) = domainservice::read_domain(&ip_registry, &domain_registry, string::utf8(b"example.com"), &clock);
        assert!(owner == @0x123, 0);
        assert!(website_code == string::utf8(b"<html>test</html>"), 1);
        assert!(expiry_time > clock::timestamp_ms(&clock), 2);

        // Clean up
        domainservice::clear_test_ip_registry(&mut ip_registry, string::utf8(b"192.168.1.1"));
        domainservice::clear_test_domain_registry(&mut domain_registry, string::utf8(b"example.com"));
        domainservice::destroy_test_ip_registry(ip_registry);
        domainservice::destroy_test_domain_registry(domain_registry);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_buy_domain() {
        let mut scenario_val = test_scenario::begin(@0x123);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);
        let mut clock = clock::create_for_testing(ctx);

        // Create objects
        let mut ip_registry = domainservice::create_test_ip_registry(ctx);
        let mut domain_registry = domainservice::create_test_domain_registry(ctx);

        // Assign a domain to a different owner
        domainservice::assign_domain(
            &mut ip_registry,
            &mut domain_registry,
            string::utf8(b"example.com"),
            string::utf8(b"192.168.1.1"),
            string::utf8(b"<html>test</html>"),
            @0x456,
            &clock,
            ctx
        );

        // Switch to buyer
        test_scenario::next_tx(scenario, @0x789);
        let ctx = test_scenario::ctx(scenario);

        // Prepare payment
        let mut payment = coin::mint_for_testing<SUI>(1_000_000_000, ctx);

        // Buy the domain
        domainservice::buy_domain(
            &mut domain_registry,
            string::utf8(b"example.com"),
            payment,
            ctx
        );

        // Verify new owner
        let (owner, _, _) = domainservice::read_domain(&ip_registry, &domain_registry, string::utf8(b"example.com"), &clock);
        assert!(owner == @0x789, 0);

        // Clean up
        domainservice::clear_test_ip_registry(&mut ip_registry, string::utf8(b"192.168.1.1"));
        domainservice::clear_test_domain_registry(&mut domain_registry, string::utf8(b"example.com"));
        domainservice::destroy_test_ip_registry(ip_registry);
        domainservice::destroy_test_domain_registry(domain_registry);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = domainservice::EAlreadyOwner)]
    fun test_buy_domain_already_owned() {
        let mut scenario_val = test_scenario::begin(@0x123);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);
        let mut clock = clock::create_for_testing(ctx);

        // Create objects
        let mut ip_registry = domainservice::create_test_ip_registry(ctx);
        let mut domain_registry = domainservice::create_test_domain_registry(ctx);

        // Assign a domain to the same owner
        domainservice::assign_domain(
            &mut ip_registry,
            &mut domain_registry,
            string::utf8(b"example.com"),
            string::utf8(b"192.168.1.1"),
            string::utf8(b"<html>test</html>"),
            @0x123,
            &clock,
            ctx
        );

        // Try to buy own domain
        let mut payment = coin::mint_for_testing<SUI>(1_000_000_000, ctx);
        domainservice::buy_domain(
            &mut domain_registry,
            string::utf8(b"example.com"),
            payment,
            ctx
        );

        // Clean up
        domainservice::clear_test_ip_registry(&mut ip_registry, string::utf8(b"192.168.1.1"));
        domainservice::clear_test_domain_registry(&mut domain_registry, string::utf8(b"example.com"));
        domainservice::destroy_test_ip_registry(ip_registry);
        domainservice::destroy_test_domain_registry(domain_registry);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = domainservice::EDomainNotFound)]
    fun test_expired_domain() {
        let mut scenario_val = test_scenario::begin(@0x123);
        let scenario = &mut scenario_val;
        let ctx = test_scenario::ctx(scenario);
        let mut clock = clock::create_for_testing(ctx);

        // Create objects
        let mut ip_registry = domainservice::create_test_ip_registry(ctx);
        let mut domain_registry = domainservice::create_test_domain_registry(ctx);

        // Assign a domain
        domainservice::assign_domain(
            &mut ip_registry,
            &mut domain_registry,
            string::utf8(b"example.com"),
            string::utf8(b"192.168.1.1"),
            string::utf8(b"<html>test</html>"),
            @0x123,
            &clock,
            ctx
        );

        // Fast-forward clock past expiry
        clock::increment_for_testing(&mut clock, 365 * 24 * 60 * 60 * 1000 + 1000);

        // Try to read expired domain
        domainservice::read_domain(&ip_registry, &domain_registry, string::utf8(b"example.com"), &clock);

        // Clean up
        domainservice::clear_test_ip_registry(&mut ip_registry, string::utf8(b"192.168.1.1"));
        domainservice::clear_test_domain_registry(&mut domain_registry, string::utf8(b"example.com"));
        domainservice::destroy_test_ip_registry(ip_registry);
        domainservice::destroy_test_domain_registry(domain_registry);
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
}
