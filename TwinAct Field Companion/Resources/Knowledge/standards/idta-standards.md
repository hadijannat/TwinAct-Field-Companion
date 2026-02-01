# IDTA Standards and Specifications

## Industrial Digital Twin Association (IDTA)

The IDTA is the international user organization for the Asset Administration Shell and digital twins. It develops, maintains, and promotes AAS standards through working groups composed of industry experts.

**Website:** https://industrialdigitaltwin.org
**Founded:** 2021 (merger of ZVEI and VDMA initiatives)

## Core Specifications

### IDTA 01001 - Metamodel

**Full title:** Specification of the Asset Administration Shell - Part 1: Metamodel

**Current version:** V3.0

**Content:**
- Formal definition of AAS structure
- UML class diagrams
- Element definitions and relationships
- Identifier requirements
- Constraint rules

**Key elements defined:**
- AssetAdministrationShell
- Asset
- Submodel
- SubmodelElement (and all subtypes)
- ConceptDescription
- Reference structures

### IDTA 01002 - API

**Full title:** Specification of the Asset Administration Shell - Part 2: Application Programming Interfaces

**Current version:** V3.0

**Content:**
- REST API specification (OpenAPI)
- HTTP methods and endpoints
- Request/response formats
- Error handling
- Pagination patterns

**Key endpoints:**
```
GET /shells                      # List all AAS
GET /shells/{aasId}              # Get specific AAS
GET /submodels                   # List all submodels
GET /submodels/{smId}            # Get specific submodel
GET /submodels/{smId}/submodel-elements/{path}
POST /shells                     # Create AAS
PUT /shells/{aasId}              # Update AAS
DELETE /shells/{aasId}           # Delete AAS
```

**Discovery endpoints:**
```
GET /lookup/shells               # Discover AAS by asset ID
GET /description                 # Server capabilities
```

### IDTA 01003 - Security

**Full title:** Specification of the Asset Administration Shell - Part 3a: Security

**Content:**
- Access control models
- Authentication methods
- Authorization frameworks
- Security attribute handling

### IDTA 01005 - AASX

**Full title:** Specification of the Asset Administration Shell - Part 5: Package File Format (AASX)

**Content:**
- OPC-based package structure
- Relationship types
- Content type mappings
- Signing and verification

**Package structure:**
```
*.aasx (ZIP format)
├── [Content_Types].xml          # MIME type mappings
├── _rels/
│   └── .rels                    # Root relationships
├── aasx/
│   ├── _rels/
│   │   └── aasx-origin.rels     # AAS relationships
│   ├── aas.json or aas.xml      # AAS content
│   └── aasx-origin              # Package origin marker
├── aasx/thumbnail/              # Asset image
└── aasx/documents/              # Embedded files
```

## Submodel Templates

### IDTA 02002 - Contact Information
- Contact type taxonomy
- Multi-language support
- Structured address format

### IDTA 02003 - Technical Data
- Product classifications
- Technical properties
- Unit handling

### IDTA 02004 - Handover Documentation
- Document classification
- Version management
- Multi-language titles
- File references

### IDTA 02006 - Digital Nameplate
- Manufacturer identification
- Product marking
- Regulatory information
- Contact references

### IDTA 02008 - Time Series Data
- Record structure
- Segment organization
- External data linking

### IDTA 02010 - Service Request
- Request lifecycle
- Field technician workflows
- Status tracking

### IDTA 02011 - Hierarchical Structures
- Bill of materials
- Assembly relationships
- Part-of structures

### IDTA 02019 - Software Nameplate
- Software identification
- Version tracking
- Installation records

### IDTA 02029 - Carbon Footprint
- Product carbon footprint (PCF)
- Transport carbon footprint (TCF)
- Use phase carbon footprint (UCF)
- End-of-life carbon footprint (EOLCF)
- Verification information

## Implementation Guidelines

### IDTA 01004 - Best Practices

**Identifier guidelines:**
- Use IRIs (URLs) for global identifiers
- Use camelCase for idShort
- Ensure uniqueness within scope
- Consider URL encoding issues

**Semantic ID usage:**
- Always provide semantic IDs for standard elements
- Use ECLASS or IDTA catalogs
- Create concept descriptions for custom elements
- Reference authoritative sources

**File handling:**
- Use relative paths within AASX
- Respect content type conventions
- Include appropriate thumbnails
- Handle large files appropriately

## ECLASS Integration

ECLASS provides a standardized classification system and property dictionary that integrates with AAS:

**Usage:**
- Product classification (ECLASS codes)
- Property definitions (IRDI-based semantic IDs)
- Unit codes (UNECE recommendations)

**Example ECLASS semantic ID:**
```
0173-1#02-AAB123#004
```
- 0173-1: Data dictionary identifier
- 02: Supplier code
- AAB123: Property ID
- 004: Version

## Conformance Testing

### AAS Test Suites
IDTA provides test tools for:
- Metamodel conformance
- API implementation verification
- AASX package validation
- Submodel template compliance

### Certification Program
- Conformance certification for tools
- Implementation guidelines adherence
- Interoperability testing

## Relationship to DPP

IDTA coordinates with European Commission on DPP technical implementation:
- AAS as DPP technical foundation
- Submodel mapping to DPP requirements
- Interoperability specifications
- Registry and resolver requirements

The Carbon Footprint submodel (IDTA 02029) directly supports Battery Regulation and ESPR carbon footprint disclosure requirements.
