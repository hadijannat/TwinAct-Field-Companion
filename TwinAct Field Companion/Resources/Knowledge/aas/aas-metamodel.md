# AAS Metamodel and Structure

## Metamodel Specification

The AAS metamodel is defined in IDTA specification 01001-3-0 "Specification of the Asset Administration Shell - Part 1: Metamodel". This document establishes the formal structure that all AAS implementations must follow.

## Metamodel Elements

### AssetAdministrationShell
The root element representing the digital twin container.

**Key Properties:**
- `id` - Globally unique identifier (IRI format recommended)
- `idShort` - Human-readable short name
- `assetInformation` - Reference to the physical asset
- `submodels` - References to contained submodels
- `derivedFrom` - Reference to a template AAS (optional)

### Asset Information
Describes the physical or logical asset.

**Key Properties:**
- `assetKind` - Either "Instance" (specific product) or "Type" (product model)
- `globalAssetId` - Unique identifier for the asset
- `specificAssetIds` - Additional identifiers (serial number, batch number)
- `assetType` - Classification of the asset
- `thumbnail` - Representative image

### Submodel
A self-contained information package about one aspect of the asset.

**Key Properties:**
- `id` - Globally unique identifier
- `idShort` - Human-readable short name
- `semanticId` - Reference to the submodel template definition
- `kind` - "Instance" or "Template"
- `submodelElements` - Contained data elements

### SubmodelElement Types

**Property** - Single value with data type
```
{
  "idShort": "SerialNumber",
  "semanticId": "https://admin-shell.io/...",
  "valueType": "xs:string",
  "value": "ABC-12345"
}
```

**SubmodelElementCollection** - Grouped elements
```
{
  "idShort": "ContactInfo",
  "value": [
    {"idShort": "Name", "value": "Acme Corp"},
    {"idShort": "Phone", "value": "+1-555-0100"}
  ]
}
```

**File** - External document reference
```
{
  "idShort": "Manual",
  "contentType": "application/pdf",
  "value": "/aasx/documents/manual.pdf"
}
```

**MultiLanguageProperty** - Values in multiple languages
```
{
  "idShort": "ProductName",
  "value": [
    {"language": "en", "text": "Electric Motor"},
    {"language": "de", "text": "Elektromotor"}
  ]
}
```

**ReferenceElement** - Link to other elements
**Range** - Numeric range (min/max)
**Blob** - Embedded binary data
**Entity** - Composite asset reference
**Operation** - Executable function (API)
**Capability** - Functionality description
**AnnotatedRelationshipElement** - Typed relationships

## Semantic IDs

Semantic IDs provide globally unique meaning definitions for data elements. They typically use IRIs (Internationalized Resource Identifiers).

**Example Semantic IDs:**
- `https://admin-shell.io/ZVEI/TechnicalData/ProductClassifications/ProductClassificationItem/1/0` - Product classification
- `https://admin-shell.io/idta/CarbonFootprint/ProductCarbonFootprint/0/9` - Carbon footprint data

**Benefits:**
- Machine-readable meaning
- Cross-system interoperability
- Standard vocabularies via ECLASS, IDTA catalogs
- Enables semantic search and validation

## Concept Descriptions

Concept Descriptions define the meaning, data type, and constraints for submodel elements. They're stored in a dictionary and referenced by semantic ID.

**Structure:**
- `id` - Matches the semantic ID
- `idShort` - Human-readable name
- `description` - Multi-language explanation
- `embeddedDataSpecifications` - Data type details, units, value ranges

## Identifiers

### Global Unique Identifiers
Required for AAS, Submodels, and ConceptDescriptions. Use IRI format:
- `https://example.com/aas/12345`
- `urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6`

### Short Identifiers (idShort)
Human-readable names within a context. Must be unique within their container. Use camelCase without spaces.

### Specific Asset IDs
Product-specific identifiers:
- Serial numbers
- Batch numbers
- Internal part numbers
- Customer order references
