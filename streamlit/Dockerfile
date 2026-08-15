FROM python:3.12-slim

# Non-root, and the uid is fixed so the Deployment's runAsUser matches.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Requirements first: this layer is cached unless the pins change, so an app.py
# edit rebuilds in seconds rather than re-resolving every wheel.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

USER 10001
EXPOSE 8501

# Streamlit's usage stats phone home by default, and its XSRF/CORS defaults
# assume a browser origin it can see — behind a LoadBalancer it cannot.
ENV STREAMLIT_BROWSER_GATHER_USAGE_STATS=false \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0 \
    STREAMLIT_SERVER_PORT=8501

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8501/_stcore/health')"

CMD ["streamlit", "run", "app.py"]
