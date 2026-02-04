const express = require("express");
const cors = require("cors");
const {
  Document,
  Packer,
  Paragraph,
  TextRun,
  ImageRun,
  HeadingLevel,
  AlignmentType,
  PageBreak,
} = require("docx");
const axios = require("axios");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Endpoint to generate DOCX from reports
app.post("/api/export-reports", async (req, res) => {
  try {
    const { reports } = req.body;

    if (!reports || !Array.isArray(reports)) {
      return res.status(400).json({ error: "Invalid reports data" });
    }

    // Create document sections
    const sections = [];

    for (const report of reports) {
      const children = [];

      // Add date as heading
      children.push(
        new Paragraph({
          heading: HeadingLevel.HEADING_1,
          children: [
            new TextRun({
              text: new Date(report.date).toLocaleDateString("en-US", {
                weekday: "long",
                year: "numeric",
                month: "long",
                day: "numeric",
              }),
              bold: true,
            }),
          ],
          spacing: { after: 200 },
        }),
      );

      // Add title
      children.push(
        new Paragraph({
          heading: HeadingLevel.HEADING_2,
          children: [
            new TextRun({
              text: report.title,
              bold: true,
            }),
          ],
          spacing: { after: 200 },
        }),
      );

      // Add image if available
      if (report.imageUrl) {
        try {
          const imageResponse = await axios.get(report.imageUrl, {
            responseType: "arraybuffer",
          });

          const imageBuffer = Buffer.from(imageResponse.data);

          // Determine image type from URL or content-type
          let imageType = "png";
          const contentType = imageResponse.headers["content-type"];
          if (contentType.includes("jpeg") || contentType.includes("jpg")) {
            imageType = "jpg";
          }

          children.push(
            new Paragraph({
              children: [
                new ImageRun({
                  data: imageBuffer,
                  transformation: {
                    width: 500,
                    height: 375,
                  },
                  type: imageType,
                }),
              ],
              spacing: { after: 200 },
              alignment: AlignmentType.CENTER,
            }),
          );
        } catch (imageError) {
          console.error("Error loading image:", imageError);
          // Continue without image if it fails
        }
      }

      // Add narrative text (split by paragraphs)
      const narrativeParagraphs = report.narrative
        .split("\n")
        .filter((p) => p.trim());

      for (const para of narrativeParagraphs) {
        children.push(
          new Paragraph({
            children: [
              new TextRun({
                text: para.trim(),
              }),
            ],
            spacing: { after: 120 },
          }),
        );
      }

      // Add page break between reports (except for the last one)
      if (reports.indexOf(report) < reports.length - 1) {
        children.push(
          new Paragraph({
            children: [new PageBreak()],
          }),
        );
      }

      sections.push(...children);
    }

    // Create the document
    const doc = new Document({
      styles: {
        default: {
          document: {
            run: {
              font: "Arial",
              size: 24, // 12pt
            },
          },
        },
        paragraphStyles: [
          {
            id: "Heading1",
            name: "Heading 1",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: {
              size: 32, // 16pt
              bold: true,
              font: "Arial",
            },
            paragraph: {
              spacing: { before: 240, after: 240 },
              outlineLevel: 0,
            },
          },
          {
            id: "Heading2",
            name: "Heading 2",
            basedOn: "Normal",
            next: "Normal",
            quickFormat: true,
            run: {
              size: 28, // 14pt
              bold: true,
              font: "Arial",
            },
            paragraph: {
              spacing: { before: 180, after: 180 },
              outlineLevel: 1,
            },
          },
        ],
      },
      sections: [
        {
          properties: {
            page: {
              size: {
                width: 12240, // 8.5 inches
                height: 15840, // 11 inches
              },
              margin: {
                top: 1440, // 1 inch
                right: 1440,
                bottom: 1440,
                left: 1440,
              },
            },
          },
          children: [
            // Cover page
            new Paragraph({
              heading: HeadingLevel.TITLE,
              children: [
                new TextRun({
                  text: "OJT Narrative Reports",
                  bold: true,
                  size: 48, // 24pt
                }),
              ],
              spacing: { before: 2880, after: 240 }, // 2 inches before
              alignment: AlignmentType.CENTER,
            }),
            new Paragraph({
              children: [
                new TextRun({
                  text: `Generated on ${new Date().toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "long",
                    day: "numeric",
                  })}`,
                  size: 24,
                }),
              ],
              spacing: { after: 240 },
              alignment: AlignmentType.CENTER,
            }),
            new Paragraph({
              children: [new PageBreak()],
            }),
            // Add all report sections
            ...sections,
          ],
        },
      ],
    });

    // Generate buffer
    const buffer = await Packer.toBuffer(doc);

    // Set headers for download
    const fileName = `OJT_Reports_${new Date().toISOString().split("T")[0]}.docx`;
    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    );
    res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);

    res.send(buffer);
  } catch (error) {
    console.error("Error generating DOCX:", error);
    res
      .status(500)
      .json({ error: "Failed to generate document", details: error.message });
  }
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.listen(PORT, () => {
  console.log(`Export service running on port ${PORT}`);
});
