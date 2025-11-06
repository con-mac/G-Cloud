# Mock SharePoint Structure

This directory contains a local mock of the SharePoint structure for development and testing purposes.

## Structure

```
mock_sharepoint/
├── GCloud 14/
│   └── PA Services/
│       ├── Cloud Support Services LOT 2/
│       │   ├── Test Title/
│       │   │   └── OWNER John Smith.txt
│       │   └── Agile Test Title/
│       │       └── OWNER Jane Doe.txt
│       └── Cloud Support Services LOT 3/
│           └── Test Title v2/
│               └── OWNER Bob Johnson.txt
└── GCloud 15/
    └── PA Services/
        ├── Cloud Support Services LOT 2/
        └── Cloud Support Services LOT 3/
```

## Seeded Documents

### GCloud 14 - LOT 2

#### Test Title
- **Metadata**: `OWNER John Smith.txt`
- **Service**: Test Title
- **Owner**: John Smith
- **Sponsor**: Jane Doe
- **Expected Documents**:
  - `PA GC14 SERVICE DESC Test Title.docx`
  - `PA GC14 SERVICE DESC Test Title.pdf`
  - `PA GC14 Pricing Doc Test Title.docx`
  - `PA GC14 Pricing Doc Test Title.pdf`

#### Agile Test Title
- **Metadata**: `OWNER Jane Doe.txt`
- **Service**: Agile Test Title
- **Owner**: Jane Doe
- **Sponsor**: John Smith
- **Expected Documents**:
  - `PA GC14 SERVICE DESC Agile Test Title.docx`
  - `PA GC14 SERVICE DESC Agile Test Title.pdf`
  - `PA GC14 Pricing Doc Agile Test Title.docx`
  - `PA GC14 Pricing Doc Agile Test Title.pdf`

### GCloud 14 - LOT 3

#### Test Title v2
- **Metadata**: `OWNER Bob Johnson.txt`
- **Service**: Test Title v2
- **Owner**: Bob Johnson
- **Sponsor**: Alice Williams
- **Expected Documents**:
  - `PA GC14 SERVICE DESC Test Title v2.docx`
  - `PA GC14 SERVICE DESC Test Title v2.pdf`
  - `PA GC14 Pricing Doc Test Title v2.docx`
  - `PA GC14 Pricing Doc Test Title v2.pdf`

## Usage

This mock structure is used for:
1. **Development**: Build and test SharePoint integration without requiring actual SharePoint access
2. **Testing**: Test search functionality, fuzzy matching, and document operations
3. **Validation**: Verify folder structure and naming conventions

## Metadata File Format

All `.txt` metadata files follow this exact format:
```
1. SERVICE: [Service Name]
2. OWNER: [First name] [Last name]
3. SPONSOR: [First name] [Last name]
```

## Document Naming

- **Service Description**: `PA GC14 SERVICE DESC [Service Name].docx/.pdf`
- **Pricing Document**: `PA GC14 Pricing Doc [Service Name].docx/.pdf`
- **Metadata File**: `OWNER [First name] [Last name].txt`

## Search Testing

Use these service names to test fuzzy search:
- "Test Title" (should match "Test Title", "Test Title v2")
- "test title" (case-insensitive)
- "TEST TITLE" (uppercase)
- "Agile" (should match "Agile Test Title")
- "v2" (should match "Test Title v2")

