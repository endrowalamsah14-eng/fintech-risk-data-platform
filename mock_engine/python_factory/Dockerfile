FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy logic script
COPY chaos_generator.py .
COPY db_injector.py . 

# Eksekusi injector
CMD ["python", "db_injector.py"]