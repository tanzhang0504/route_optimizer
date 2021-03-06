#set.seed(5000)

#./Rscript fun.R scheduling_mode fairness_mode f_conflict_graph_in f_throughput_in f_routes_out

#fairness_mode is a number:
#0 -> Equal time 
#1 -> Equal throughput  -> not available now
#2 -> Proportional Throughput -> NA now

#scheduling mode is a number
#kMaxThroughput = 0,
#kOptimizer = 1,
#kDuplication = 2,
#kRoundRobin = 3,
#kExhaustiveSearch = 4,


options=commandArgs(trailingOnly = TRUE)
print(options)
sche.param <- as.numeric(options[1])
fairness.param <- as.numeric(options[2])  
station.channel.file <- options[3]
data.file <- options[4]
out.file <- options[5]


#fairness.param <- 0
#sche.param <- 0
#data.file <- "thruput_example1.txt"
#station.channel.file <- "bs_channel_data1.txt"
#out.file <- "tmp.txt"

####################################
# read in functions
####################################

# equal interval strategy - if k cars are assigned to one bs, each gets the same amount of time for transmission
optf.gen <- function(mm, param){
# mm is the throughput matrix, receiver by bs
# if param is assignment matrix in vector format (binary 0 or 1),
# omit the last column (since row sum should be 1 for all rows)
# e.g. v should be r1c1, r2c1, r3c1, .. , r1c2, r2c2 ,... 
  nc <- ncol(mm)
  p1 <- matrix(param,ncol=nc-1)
	# if row sum >1 for now need to rescale..
	rs <- rowSums(p1)
	rs[which(rs==0)] <- 1
	p1.0 <- p1/rs
  p2.0 <- cbind(p1.0, 1-rowSums(p1.0))
  #p2.0 <- cbind(p1, 1-rowSums(p1))
	#print(p2.0)
	p2 <- p2.0
	#p2 <- matrix(0, ncol=nc, nrow=nrow(p2.0))
	#for(i in 1:nrow(p2))p2[i, which.max(p2.0[i,])[1]] <- 1
  #pen <- sum((p2-round(p2))^2)
  aa <- sapply(1:nc,function(i)p2[which(p2[,i]!=0),i] ,simplify=F)
  bb <- sapply(aa, function(i) i * (1/sum(i)),simplify=F)
  cc <- sapply(1:nc, function(i)mm[which(p2[,i]!=0),i] * bb[[i]])
  -sum(unlist(cc)) #+ lam*pen
}

# proportional
optf.pro <- function(mm, param){
  nc <- ncol(mm)
  p1 <- matrix(param,ncol=nc-1)
	rs <- rowSums(p1)
	rs[which(rs==0)] <- 1
	p1.0 <- p1/rs
  p2.0 <- cbind(p1.0, 1-rowSums(p1.0))
	p2 <- p2.0
  #aa <- sapply(1:nc,function(i)p2[which(p2[,i]!=0),i] ,simplify=F)
	a2 <- sapply(1:nc,function(i)mm[which(p2[,i]!=0),i] ,simplify=F)
  bb <- sapply(a2, function(i) i * (1/sum(i)),simplify=F)
  cc <- sapply(1:nc, function(i)a2[[i]] * bb[[i]])
  -sum(unlist(cc)) #+ lam*pen
}


optf.inv <- function(mm, param){
  nc <- ncol(mm)
  p1 <- matrix(param,ncol=nc-1)
	rs <- rowSums(p1)
	rs[which(rs==0)] <- 1
	p1.0 <- p1/rs
  p2.0 <- cbind(p1.0, 1-rowSums(p1.0))
	p2 <- p2.0
	#print(p2)
  #aa <- sapply(1:nc,function(i)p2[which(p2[,i]!=0),i] ,simplify=F)
	a2 <- sapply(1:nc,function(i)mm[which(p2[,i]!=0),i] ,simplify=F)
	a3 <- sapply(a2, function(i){
		tmp <- 1/i
		tmp[which(tmp==Inf)] <- 0
		tmp
		})
  bb <- sapply(a3, function(i) i * (1/sum(i)),simplify=F)
  cc <- sapply(1:nc, function(i)a2[[i]] * bb[[i]])
  -sum(unlist(cc)) #+ lam*pen
}



# convert function
v.to.matv <- function(v, nr, nc){
tmpmat.max <- matrix(0,nrow=nr,ncol=nc)
for(i in 1:nc)tmpmat.max[which(v==i),i]=1
v.max.use <- as.vector(tmpmat.max[,1:(nc-1)])
}

matv.to.v <- function(matv, nr, nc){
mat.res0 <- matrix(matv,nrow=nr, ncol=nc-1)
mat.res <- cbind(mat.res0, 1-rowSums(mat.res0))
v.res <- apply(mat.res, 1, function(i)which.max(i)[1])
}
	

cn.to.bs <- function(cn.name, n.car, cn.lev, cn.multi, station.channel, assign.multi){
  bs.out <- rep(NA, n.car)
  for(i in cn.lev){
	  tmp <- which(cn.name==i)
    if(length(tmp)>0){
		    if(!i%in%cn.multi)bs.out[tmp] <- rep(names(station.channel)[which(station.channel==i)],length(tmp))
	    else bs.out[tmp] <- assign.multi[tmp,i]
			  }
}
out <- as.numeric(gsub("bs","",bs.out))
}

browser()
#############################
# Read in data
#############################
data.in.raw <- data.matrix(read.table(data.file))
data.in.raw[which(data.in.raw<0)] <- 0 # -1 may represent missing data
station.channel.in <- data.matrix(read.table(station.channel.file))
n.bs.raw <- ncol(data.in.raw)
n.car.raw <- nrow(data.in.raw)
colnames(data.in.raw) <- paste("bs",station.channel.in[,1],sep="")
rownames(data.in.raw) <- paste("client",1:n.car.raw,sep="")
station.channel.raw <- paste("channel",station.channel.in[,2],sep="")
names(station.channel.raw) <- paste("bs", station.channel.in[,1],sep="")

if(!identical(names(station.channel.raw), colnames(data.in.raw)))stop("base stations in two files don't match!")

# client with no trafic
which.0 <- which(rowSums(data.in.raw)==0)
data.in <- data.in.raw
station.channel <- station.channel.raw
if(length(which.0)>0){
	data.in <- matrix(data.in.raw[-which.0,],ncol=n.bs.raw)
	#name.0 <- rownames(data.in.raw)[which.0]
}
# bs with no trafic
n.car <- nrow(data.in)
which.bs.0 <- which(colSums(data.in.raw)==0)
if(length(which.bs.0)>0){
  data.in <- matrix(data.in[,-which.bs.0],nrow=n.car)
  station.channel <- station.channel.raw[-which.bs.0]
}
b.bs <- ncol(data.in)
if(ncol(data.in)==1){
	out.final <- rep(gsub("bs","",colnames(data.in)), n.bs.raw)
	write.table(out.final, file=out.file, quote=F, col.names=F, row.names=F)
	stop("only one available bs; results returned")
	}
###################################
# deal with stations within channel
# can take the best one in the channel
# Then perform assignment across channels
# since while multiple bs's share the same channel, only one of them can
# send out packet!
###################################

channel.tab <- table(station.channel)
channel.lev <- names(channel.tab)
n.channel <- length(channel.lev)

# for channels with more than 1 bs, take the max thruput one
cn.multi <- channel.lev[which(channel.tab>1)]
n.cn.multi <- length(cn.multi)
# don worry about channels with single bs
mat.single <- NULL
if (n.cn.multi < n.channel){
  mat.single <- matrix(data.in[,which(!station.channel%in%cn.multi)],nrow=n.car)
  colnames(mat.single) <- station.channel[which(!station.channel%in%cn.multi)]
}

mat.multi <- NULL
if (n.cn.multi > 0 ){
  mat.multi <- assign.multi <- matrix(NA, nrow=n.car, ncol=n.cn.multi,
																			dimnames=list(rownames(data.in),cn.multi))
	for(i in cn.multi){
		tmpdata <- data.in[,which(station.channel==i)]
	  mat.multi[,i] <- apply(tmpdata,1,max)
	  assign.multi[,i] <- apply(tmpdata, 1, function(i)names(i)[which.max(i)[1]])
	}
}

# channle thruput matrix
mat.channel <- cbind(mat.single, mat.multi)

initiate.assign <- matrix(0, nrow=n.car, ncol=n.channel)
for(i in 1:n.car)initiate.assign[i,sample(1:n.channel,1)] <- 1




###################################
# which max - independent of scheduling
###################################
if(sche.param==0){
max.cn.idx <- apply(mat.channel,1,function(i)which.max(i)[1])
max.cn.name <- colnames(mat.channel)[max.cn.idx]
max.out <- cn.to.bs(max.cn.name,n.car, channel.lev, cn.multi, 
										station.channel, assign.multi)
if(fairness.param==0)tp.res.max <- abs(optf.gen(mat.channel, v.to.matv(max.cn.idx, n.car, n.channel)))
if(fairness.param==1)tp.res.max <- abs(optf.inv(mat.channel, v.to.matv(max.cn.idx, n.car, n.channel)))
if(fairness.param==2)tp.res.max <- abs(optf.pro(mat.channel, v.to.matv(max.cn.idx, n.car, n.channel)))	
message("overall throughput ", tp.res.max)
out.v <- max.out
}


##################################
# optimizer
##################################

if(sche.param==1){ #optimizer

##################################
# even thruput
##################################
if(fairness.param==0){
max.cn.idx <- apply(mat.channel,1,function(i)which.max(i)[1])
max.cn.in.v <- v.to.matv(max.cn.idx, n.car, n.channel)
#res.even <- optim(par=as.vector(initiate.assign[,1:(n.channel-1)]), 
# use max as start point?
res.even.try <- try(optim(par=max.cn.in.v, 
	optf.gen, mm=mat.channel, lower=0, upper=1,
	control=list(maxit = 20000, temp = 20, parscale=rep(10^6,length(max.cn.in.v))),
									method="L-BFGS-B"),silent=T)
if(class(res.even.try)!="try-error")res.even <- res.even.try
if(class(res.even.try)=="try-error")res.even <- try(optim(par=max.cn.in.v,
						  optf.gen, mm=mat.channel, lower=0, upper=1,method="L-BFGS-B"))
if(class(res.even)!="try-error")v.res.even <- res.even$par
if(class(res.even)=="try-error")v.res.even <- max.cn.in.v # return max if error after 2 try
even.cn.idx <- matv.to.v(v.res.even, n.car, n.channel)
# convert channel names back to bs names
even.cn.name <- colnames(mat.channel)[even.cn.idx]
even.out <- cn.to.bs(even.cn.name,n.car, channel.lev, cn.multi, station.channel, assign.multi)
tp.res.even <- abs(optf.gen(mat.channel, v.to.matv(even.cn.idx, n.car, n.channel))) # even time within channel so use channel matrix
message("overall throughput ", tp.res.even)
out.v <- even.out
}

if(fairness.param==1){
max.cn.idx <- apply(mat.channel,1,function(i)which.max(i)[1])
max.cn.in.v <- v.to.matv(max.cn.idx, n.car, n.channel)
# use max as start point?
res.inv.try <- try(optim(par=max.cn.in.v, 
	optf.inv, mm=mat.channel, lower=0, upper=1,
	control=list(maxit = 20000, temp = 20, parscale=rep(10^6,length(max.cn.in.v))),
									method="L-BFGS-B"), silent=T)
if(class(res.inv.try)!="try-error")res.inv <- res.inv.try
if(class(res.inv.try)=="try-error")res.inv <- try(optim(par=max.cn.in.v,
									optf.inv, mm=mat.channel, lower=0, upper=1,method="L-BFGS-B"))

if(class(res.inv)!="try-error")v.res.inv <- res.inv$par
if(class(res.inv)=="try-error")v.res.inv <- max.cn.in.v # return max if error after 2 try
inv.cn.idx <- matv.to.v(v.res.inv, n.car, n.channel)
# convert channel names back to bs names
inv.cn.name <- colnames(mat.channel)[inv.cn.idx]
inv.out <- cn.to.bs(inv.cn.name,n.car, channel.lev, cn.multi, station.channel, assign.multi)
tp.res.inv <- abs(optf.inv(mat.channel, v.to.matv(inv.cn.idx, n.car, n.channel))) # inv time within channel so use channel matrix
message("overall throughput ", tp.res.inv)
out.v <- inv.out
}

if(fairness.param==2){
max.cn.idx <- apply(mat.channel,1,function(i)which.max(i)[1])
max.cn.in.v <- v.to.matv(max.cn.idx, n.car, n.channel)
# use max as start point?
res.pro.try <- try(optim(par=max.cn.in.v, 
	optf.pro, mm=mat.channel, lower=0, upper=1,
	control=list(maxit = 20000, temp = 20, parscale=rep(10^6,length(max.cn.in.v))),
									method="L-BFGS-B"),silent=T)
if(class(res.pro.try)!="try-error")res.pro <- res.pro.try
if(class(res.pro.try)=="try-error")res.pro <- try(optim(par=max.cn.in.v, 
				optf.pro, mm=mat.channel, lower=0, upper=1,method="L-BFGS-B"))
if(class(res.pro)!="try-error")v.res.pro <- res.pro$par
if(class(res.pro)=="try-error")v.res.pro <- max.cn.in.v # return max if error after 2 try
pro.cn.idx <- matv.to.v(v.res.pro, n.car, n.channel)
# convert channel names back to bs names
pro.cn.name <- colnames(mat.channel)[pro.cn.idx]
pro.out <- cn.to.bs(pro.cn.name,n.car, channel.lev, cn.multi, station.channel, assign.multi)
tp.res.pro <- abs(optf.pro(mat.channel, v.to.matv(pro.cn.idx, n.car, n.channel))) # pro time within channel so use channel matrix
message("overall throughput ", tp.res.pro)
out.v <- pro.out
}


}
###################################
# search
###################################
if(sche.param==4){ #search over all possible combinations


list.for.expand <- vector("list", n.car)
for(i in 1:n.car)list.for.expand[[i]] <- 1:n.channel
expand.tab <- expand.grid(list.for.expand)

################
# even time
################
if(fairness.param==0){
all.expand.res <- apply(expand.tab, 1, function(i)abs(optf.gen(mat.channel, v.to.matv(i, n.car, n.channel))))
which.max.expand <- which.max(all.expand.res)
expand.cn.idx <- as.numeric(expand.tab[which.max.expand,])
expand.cn.name <- colnames(mat.channel)[expand.cn.idx]
expand.out <- cn.to.bs(expand.cn.name,n.car, channel.lev, cn.multi,
										                    station.channel, assign.multi)
tp.res.expand <- abs(optf.gen(mat.channel, v.to.matv(expand.cn.idx, n.car, n.channel)))
message("overall throughput ", tp.res.expand)
out.v <- expand.out
}
if(fairness.param==1){
all.expand.res <- apply(expand.tab, 1, function(i)abs(optf.inv(mat.channel, v.to.matv(i, n.car, n.channel))))
which.max.expand <- which.max(all.expand.res)
expand.cn.idx <- as.numeric(expand.tab[which.max.expand,])
expand.cn.name <- colnames(mat.channel)[expand.cn.idx]
expand.out <- cn.to.bs(expand.cn.name,n.car, channel.lev, cn.multi,
										                    station.channel, assign.multi)
tp.res.expand <- abs(optf.inv(mat.channel, v.to.matv(expand.cn.idx, n.car, n.channel)))
message("overall throughput ", tp.res.expand)
out.v <- expand.out
}


if(fairness.param==2){
all.expand.res <- apply(expand.tab, 1, function(i)abs(optf.pro(mat.channel, v.to.matv(i, n.car, n.channel))))
which.max.expand <- which.max(all.expand.res)
expand.cn.idx <- as.numeric(expand.tab[which.max.expand,])
expand.cn.name <- colnames(mat.channel)[expand.cn.idx]
expand.out <- cn.to.bs(expand.cn.name,n.car, channel.lev, cn.multi,
										                    station.channel, assign.multi)
tp.res.expand <- abs(optf.pro(mat.channel, v.to.matv(expand.cn.idx, n.car, n.channel)))
message("overall throughput ", tp.res.expand)
out.v <- expand.out
}


}

if(length(which.0)==0) out.final <- out.v
if(length(which.0)>0){
		out.final <- rep(-1,n.car.raw)
		out.final[-which.0] <- out.v
		}
write.table(out.final, file=out.file, quote=F, col.names=F, row.names=F)

