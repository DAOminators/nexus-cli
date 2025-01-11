FROM python:3.11-slim

RUN apt-get update
RUN apt-get install -y curl

# installing stratvim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
RUN chmod u+x nvim.appimage
RUN mv ./nvim.appimage /bin/nvim
RUN apt update
RUN apt install npm xclip git -y
RUN git clone https://github.com/StratOS-Linux/StratVIM.git ~/.config/nvim
RUN /bin/nvim --appimage-extract-and-run -c 'PlugInstall' -c 'qa'
RUN alias vim="/bin/nvim --appimage-extract-and-run"
RUN echo "alias vim='/bin/nvim --appimage-extract-and-run'" >> ~/.bashrc
RUN echo "alias vi='/bin/nvim --appimage-extract-and-run'" >> ~/.bashrc
RUN echo "alias nvim='/bin/nvim --appimage-extract-and-run'" >> ~/.bashrc

#nexux-cli dependencies
RUN pip install argparse web3 ipfshttpclient eth_utils rlp

# moving reqired file
COPY nexus-cli /bin/nexus
COPY nxxs /bin/nxxs
COPY contracts /bin/contracts

CMD ["/bin/bash"]

