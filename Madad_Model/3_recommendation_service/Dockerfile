FROM python:3.11-slim
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user PATH=/home/user/.local/bin:$PATH HF_HOME=/home/user/.cache/huggingface
WORKDIR /home/user/app
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# download FashionCLIP during the build, so the first request is fast
RUN python -c "from transformers import CLIPModel, CLIPProcessor; CLIPModel.from_pretrained('patrickjohncyh/fashion-clip'); CLIPProcessor.from_pretrained('patrickjohncyh/fashion-clip')"
COPY --chown=user . .
EXPOSE 7860
# PORT is set by Cloud Run (8080); Hugging Face uses 7860
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-7860}"]
