# Polyglot Syntax Journal & Concept Indexer

A lightweight, terminal-based knowledge-graph journal designed to help developers track, link, and cross-reference programming concepts across multiple languages (Python, Java, C++, etc.). 

Instead of a flat document, this journal utilizes an inverted-index ontology model to instantly map high-level conceptual keywords (e.g., `iteration`, `count`, `sequence`) back to code syntax snippets across different languages.

---

## 🚀 Features

* **Cross-Language Reference:** View syntax for the exact same programmatic concept across multiple languages side-by-side.
* **Semantic Tag Mapping (Mini-Ontology):** Search using abstract descriptive keywords (`logic`, `branching`, `loops`) rather than strict language syntax.
* **Dynamic Inverted Indexing:** Automatically builds an in-memory concept network on startup for $O(1)$ keyword-to-concept retrieval.
* **Modular Foundation:** Data and query layers are decoupled from the display logic, making it trivial to attach a Graphical User Interface (GUI) later.

---

## 🛠️ Project Architecture

The architecture is split into three core pillars:

1. **The Knowledge Base (`dict`):** A nested dictionary structure where each node represents a unique programming concept containing metadata, relational search tags (`set`), and language-specific code snippets.
2. **The Semantic Indexer (`inverted index`):** A compiler function that maps atomic tags to a set of matching concept IDs, serving as the relational query engine.
3. **The Interface Layer (`CLI`):** An interactive terminal loop handling data presentation and search queries.

---

## 💻 Getting Started

### Prerequisites
* Python 3.6 or higher installed (No external dependencies or `pip install` required!)

### Installation & Execution
1. Clone or download the script to your local machine.
2. Save the main code file as `journal.py`.
3. Open your terminal, navigate to the directory, and run:
   ```bash
   python journal.py