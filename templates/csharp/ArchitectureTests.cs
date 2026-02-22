// Guardrail Architect — Architecture Tests (ArchUnitNET)
// Install: dotnet add package ArchUnitNET.xUnit
// Run: dotnet test --filter FullyQualifiedName~ArchitectureTests
using ArchUnitNET.Domain;
using ArchUnitNET.Fluent;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Tests.Architecture;

/// <summary>
/// Architectural rules enforced as tests.
/// Violations fail the build — agents can't break architecture silently.
/// </summary>
public class ArchitectureTests
{
    // Load all types from the production assembly
    // ← Change "YourProject" to your actual assembly name
    private static readonly ArchUnitNET.Domain.Architecture Architecture =
        new ArchLoader()
            .LoadAssemblies(typeof(YourProject.Program).Assembly)
            .Build();

    // Define layers
    private readonly IObjectProvider<IType> DomainLayer =
        Types().That().ResideInNamespace("YourProject.Domain", true).As("Domain Layer");

    private readonly IObjectProvider<IType> ServiceLayer =
        Types().That().ResideInNamespace("YourProject.Services", true).As("Service Layer");

    private readonly IObjectProvider<IType> InfrastructureLayer =
        Types().That().ResideInNamespace("YourProject.Infrastructure", true).As("Infrastructure Layer");

    private readonly IObjectProvider<IType> ApiLayer =
        Types().That().ResideInNamespace("YourProject.Api", true).As("API Layer");

    [Fact]
    public void Domain_Should_Not_Depend_On_Infrastructure()
    {
        IArchRule rule = Types().That().Are(DomainLayer)
            .Should().NotDependOnAny(InfrastructureLayer)
            .Because("Domain layer must be pure — no infrastructure dependencies");

        rule.Check(Architecture);
    }

    [Fact]
    public void Domain_Should_Not_Depend_On_Api()
    {
        IArchRule rule = Types().That().Are(DomainLayer)
            .Should().NotDependOnAny(ApiLayer)
            .Because("Domain layer must not depend on API/presentation layer");

        rule.Check(Architecture);
    }

    [Fact]
    public void Api_Should_Not_Depend_On_Infrastructure_Directly()
    {
        IArchRule rule = Types().That().Are(ApiLayer)
            .Should().NotDependOnAny(InfrastructureLayer)
            .Because("API controllers must go through services, not directly to infrastructure");

        rule.Check(Architecture);
    }

    [Fact]
    public void Services_Should_Not_Depend_On_Api()
    {
        IArchRule rule = Types().That().Are(ServiceLayer)
            .Should().NotDependOnAny(ApiLayer)
            .Because("Services must not depend on the API/presentation layer");

        rule.Check(Architecture);
    }

    [Fact]
    public void Interfaces_Should_Start_With_I()
    {
        IArchRule rule = Types().That().AreInterfaces()
            .Should().HaveNameStartingWith("I")
            .Because(".NET convention: interfaces start with I");

        rule.Check(Architecture);
    }
}
