# Glossary — every new word, in plain language

Keep this open in a second tab. When a chapter uses a **bold word** you don't know, find it
here. No definition assumes you already know another hard word.

## The basics

- **Program / script** — A list of instructions you hand to the computer, one line at a time.
  The computer does *exactly* what the list says, in order.
- **Code** — The words and symbols you write to make a program.
- **Python** — The language we write our programs in. It reads almost like English.
- **Run** — To make the computer actually *do* what your program says.
- **Terminal** (also "command line") — A text window where you type commands to the computer
  instead of clicking buttons.
- **Command** — One line you type into the terminal to tell the computer to do something.
- **Editor / VS Code** — The app where you write and save your code. VS Code is a popular,
  free one.
- **File** — A saved document. Code lives in files (Python files end in `.py`).
- **Folder / directory** — A box that holds files (and other folders).
- **Variable** — A labeled box that holds a value. `name = "Sam"` puts *Sam* in a box called
  `name`.
- **Print** — Tell the program to show a message on the screen.
- **Error** — The computer's way of saying "I didn't understand" or "something went wrong."
  Errors are normal. They tell you what to fix.
- **Install** — To add a new tool or helper onto your computer so you can use it.

## Keeping your work safe and shareable

- **Git** — A tool that saves snapshots of your project so you can go back in time and never
  lose work.
- **Commit** — One saved snapshot of your project at a moment in time.
- **GitHub** — A website that stores your project online so others (and other computers) can
  see it and work with it.
- **Push** — Send your saved snapshots up to GitHub.
- **Repository (repo)** — The whole project folder that Git is tracking.
- **Virtual environment (venv)** — A clean, private toolbox just for one project, so each
  project's tools don't bump into each other.

## Data and AI/ML

- **AI (Artificial Intelligence)** — Software that does things that usually need human smarts,
  like spotting patterns or writing text.
- **ML (Machine Learning)** — A kind of AI where the computer *learns from examples* instead
  of being told every rule.
- **Dataset** — A table of examples, like a spreadsheet with rows and columns.
- **Row** — One example in the table (like one payment).
- **Column / feature** — One kind of clue in the table (like the dollar amount).
- **Model** — A pattern-spotter that learns from examples and then makes guesses on new ones.
- **Train** — Let the model study the examples so it can guess well later.
- **Decision tree** — A simple model that works like a game of yes/no questions leading to a
  guess.
- **Fraud** — Fake or sneaky payments that should not be allowed. Our example system hunts
  for these.
- **Anomaly** — Something that doesn't fit the normal pattern; an oddity worth a closer look.
- **Train/test split** — Splitting your examples into two piles: most to study from, some kept
  hidden to quiz the model fairly.
- **Accuracy** — How often the model is right overall.
- **Precision** — When the model shouts "fraud!", how often it was actually right.
- **Recall** — Out of all the real fraud, how much the model caught.
- **MLflow** — A tool that automatically keeps a tidy notebook of every experiment you run.

## Serving and packaging

- **API** — A doorway that lets one program ask another program for something over the
  internet. ("Application Programming Interface.")
- **Endpoint** — One specific door of an API, like `/predict` or `/health`.
- **Flask** — A small Python helper for building a web service (a "front desk") others can
  talk to.
- **Request** — A message sent *to* a program asking it to do something.
- **Response** — The answer the program sends back.
- **JSON** — A simple, tidy text format for sending data between programs.
- **curl** — A command-line tool that lets you knock on an API's door from the terminal.
- **Port** — A numbered "window" on a computer that programs use to talk. Our examples use
  window `5000`.
- **Docker** — A tool that packs your program and everything it needs into a "lunchbox"
  (a *container*) so it runs the same on every computer.
- **Image** — The recipe/snapshot Docker builds. A running copy of an image is a *container*.
- **Container** — A running, packed-up copy of your program. The "lunchbox," opened and in use.
- **Dockerfile** — The recipe that tells Docker how to build the image.

## Cloud and DevOps

- **Cloud** — Renting someone else's computers over the internet instead of buying your own.
- **AWS** — Amazon's cloud, one place to rent computers and storage.
- **EC2** — A single rented computer in AWS.
- **Terraform** — A "robot builder." You write a wish-list of the cloud computers you want,
  and it builds them for you.
- **Infrastructure as code** — Writing down the computers/servers you want in a file, instead
  of clicking buttons by hand.
- **Free tier** — A small amount of cloud use that's free for new accounts. Stay inside it to
  avoid charges.
- **CI/CD** — A robot helper that automatically checks and ships your code every time you
  change it. (Continuous Integration / Continuous Delivery.)
- **GitHub Actions** — GitHub's built-in robot helper for CI/CD.
- **Kubernetes (k8s)** — A traffic controller that runs and manages *many* copies of your
  container, restarting any that fall over.
- **Deployment** — Putting your program where real people can use it.
- **Canary release** — Showing a new version to a tiny slice of users first, to catch problems
  before everyone sees them.
- **Blue/green** — Keeping two copies (old and new) and switching traffic over instantly, so
  you can switch back fast if needed.
- **Feature flag** — An on/off switch in your code for turning features on or off without
  rebuilding.

## Watching and healing

- **Monitoring / observability** — Watching your running program's health so you notice
  problems early.
- **Metric** — A number you track over time, like "requests per minute" or "errors."
- **Prometheus** — A tool that collects and stores metrics.
- **Grafana** — A tool that turns metrics into pretty, watchable dashboards (charts).
- **Dashboard** — A screen of charts showing how your system is doing right now.
- **AIOps** — Using AI to help run systems: spotting problems and even fixing them
  automatically.
- **Drift** — When the real world slowly changes so your model's old training no longer fits.
- **Retraining** — Teaching the model again on fresh data when drift shows up.

## Modern AI: smart writing robots

- **LLM (Large Language Model)** — A "super-smart pen pal": software that reads and writes text
  and can answer questions. Claude, GPT, and Gemini are examples.
- **Prompt** — The question or instructions you send to an LLM.
- **System prompt** — A standing instruction the LLM always follows (like "you are a polite
  bank helper").
- **Token** — A small piece of a word. LLMs measure their work in tokens.
- **API key** — A secret password that lets your program use a paid online service. Never put
  it directly in your code; keep it in your computer's settings.
- **RAG (Retrieval-Augmented Generation)** — Giving the LLM your *own* notes to read before it
  answers, so it answers from your facts instead of guessing.
- **Embedding** — Turning a piece of text into numbers so the computer can find similar text.
- **Vector database / ChromaDB** — A special store that holds those number-versions of text and
  finds the closest matches fast.
